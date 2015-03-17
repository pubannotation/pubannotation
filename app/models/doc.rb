class Doc < ActiveRecord::Base
  UserSourcedbSeparator = ':'
  after_save :expire_page_cache
  before_destroy :decrement_docs_counter
  after_destroy :expire_page_cache
  before_validation :attach_sourcedb_suffix
  include ApplicationHelper

  attr_accessor :username, :original_body, :text_aligner
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid, :username
  has_many :denotations, :dependent => :destroy

  has_many :subcatrels, :class_name => 'Relation', :through => :denotations, :source => :subrels

  has_many :catmods, :class_name => 'Modification', :through => :denotations, :source => :modifications
  has_many :subcatrelmods, :class_name => 'Modification', :through => :subcatrels, :source => :modifications

  has_and_belongs_to_many :projects

  validates :body,     :presence => true
  validates :sourcedb, :presence => true
  validates :sourceid, :presence => true
  validates :serial,   :presence => true
  validates_uniqueness_of :serial, scope: [:sourcedb, :sourceid]

  is_impressionable counter_cache: true, unique: :all
  
  scope :pmdocs, where(:sourcedb => 'PubMed')
  scope :pmcdocs, where(:sourcedb => 'PMC', :serial => 0)
  scope :project_name, lambda{|project_name|
    {:joins => :projects,
      :conditions => ['projects.name =?', project_name]
    }
  }

  scope :relations_count,
    # LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN instances ON instances.obj_id = denotations.id LEFT OUTER JOIN relations ON relations.subj_id = instances.id AND relations.subj_type = 'Instance'
    #joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN instances ON instances.obj_id = denotations.id LEFT OUTER JOIN relations ON relations.subj_id = instances.id AND relations.subj_type = 'Instance' LEFT OUTER JOIN denotations denotations_docs_join ON denotations_docs_join.doc_id = docs.id LEFT OUTER JOIN relations subcatrels_docs ON subcatrels_docs.subj_id = denotations_docs_join.id AND subcatrels_docs.subj_type = 'Denotation'").
    #joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN relations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation'")
    # order by subcatrels only
    joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN relations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation'")
    .group('docs.id')
    .order('count(relations.id) DESC')

  scope :projects_docs, lambda{|project_ids|
    {
      :joins => :projects,
      :conditions => ["docs_projects.project_id IN (?)", project_ids],
      :group => 'docs.id'
    }
  }

  scope :accessible_projects, lambda{|current_user_id|
    joins([:projects]).
    where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
  }
  
  scope :sql, lambda{|ids|
    where('docs.id IN(?)', ids).
    order('docs.id ASC')
  }
  
  # scope :source_db_id, lambda{|order_key_method|
  #   # source id should cast as integer
  #   order_key_method ||= 'sourcedb ASC, sourceid_int ASC'
  #   where(['sourcedb NOT ? AND sourcedb != ? AND sourceid NOT ? AND sourceid != ?', nil, '', nil, ''])
  #   .select('*, COUNT(sourcedb) AS sourcedb_count, COUNT(sourceid) AS sourceid_count, CAST(sourceid AS INT) AS sourceid_int')
  #   .group(:sourcedb).group(:sourceid).order(order_key_method)
  # }
    
  scope :source_db_id, lambda{|order_key_method|
    order_key_method ||= 'sourcedb ASC, sourceid_int ASC'
    where(['sourcedb IS NOT ? AND sourceid IS NOT ?', nil, nil])
    .select('*, CAST(sourceid AS INT) AS sourceid_int')
    .group(:id).group(:sourcedb).group(:sourceid).order(order_key_method)
  }
  
  scope :same_sourcedb_sourceid, lambda{|sourcedb, sourceid|
    where(['sourcedb = ? AND sourceid = ?', sourcedb, sourceid])
  }
  
  scope :sourcedbs, where(['sourcedb IS NOT ?', nil])

  scope :user_source_db, lambda{|username|
    where('sourcedb LIKE ?', "%#{UserSourcedbSeparator}#{username}")
  }
  
  # default sort order 
  DefaultSortArray = [['sourceid', 'ASC'], ['sourcedb', 'ASC']]
  # List of column names ignore case to sort
  CaseInsensitiveArray = %w(sourcedb)

  scope :sort_by_params, lambda{|sort_order|
    sort_order = sort_order.collect{|s| s.join(' ')}.join(', ')
    order(sort_order)
  }

  def self.get_doc(docspec)
    if docspec[:id].present?
      Doc.find(docspec[:id])
    elsif docspec[:sourcedb].present? && docspec[:sourceid].present?
      Doc.find_by_sourcedb_and_sourceid_and_serial(docspec[:sourcedb], docspec[:sourceid], docspec[:serial].present? ? docspec[:serial] : 0)
    else
      nil
    end
  end

  def self.exist?(docspec)
    !self.get_doc(docspec).nil?
  end

  def self.import(sourcedb, sourceid)
    if sourcedb.present? && sourceid.present?
      begin
        doc_sequence = Object.const_get("DocSequencer#{sourcedb}").new(sourceid)
        divs_hash = doc_sequence.divs

        divs = divs_hash.map.with_index do |div_hash, i|
          Doc.new(
            {
              :body     => div_hash[:body],
              :section  => div_hash[:heading],
              :source   => doc_sequence.source_url,
              :sourcedb => sourcedb,
              :sourceid => sourceid,
              :serial   => i
            }
          )
        end

        divs.each{|div| raise "could not save" unless div.save}

        divs
      end
    end
  end

  def self.order_by(docs, order)
    if docs.present?
      case order
      when 'denotations_count'
        docs.denotations_count
      when 'same_sourceid_denotations_count'
        # docs
          # .select('docs.*, SUM(CASE WHEN docs.sourceid = docs.sourceid THEN denotations_count ELSE 0 END) AS denotations_count_sum')
          # .group('docs.id')
          # .order('denotations_count_sum DESC')
        if docs.first.sourcedb == 'PubMed'
          docs.order('denotations_count DESC')
        else
          docs.sort{|a, b| b.same_sourceid_denotations_count <=> a.same_sourceid_denotations_count}
        end
      when 'relations_count'
        docs.relations_count
      when 'same_sourceid_relations_count'
        # docs
          # .select('docs.*, CASE WHEN docs.sourceid = docs.sourceid THEN SUM(docs.subcatrels_count) ELSE 0 END AS subcatrels_count_sum')
          # .group('docs.id')
          # .order('subcatrels_count_sum DESC')
        if docs.first.sourcedb == 'PubMed'
          docs.order('subcatrels_count DESC')
        else
          docs.sort{|a, b| b.same_sourceid_relations_count <=> a.same_sourceid_relations_count}
        end
      else
        docs.sort{|a, b| a.sourceid.to_i <=> b.sourceid.to_i}
      end
    else
      []
    end
  end    
  
  # returns relations count which belongs to project and doc
  def project_relations_count(project_id)
    count = Relation.project_relations_count(project_id, subcatrels)
  end
  
  # returns doc.relations count
  def relations_count
    subcatrels.size
  end
  
  def same_sourceid_denotations_count
    #denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
    #Denotation.select('doc_id').where('doc_id IN (?)', denotation_doc_ids).size
    Doc.where(:sourceid => self.sourceid).sum('denotations_count')
  end

  def same_sourceid_relations_count
    # denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
    # denotations_ids = Denotation.select('id, doc_id').where('doc_id IN (?)', denotation_doc_ids).collect{|denotation| denotation.id}
    # relations_size = Relation.select('subj_id, subj_type').where(:subj_type => 'Denotation').where('subj_id IN(?)', denotations_ids).size
    # instances_size = Instance.select('obj_id').where('obj_id IN(?)', denotations_ids).size
    # relations_size + instances_size
    Doc.where(:sourceid => self.sourceid).sum('subcatrels_count')
  end
  
  def span(params)
    span = {:begin => params[:begin].to_i, :end => params[:end].to_i}
    body = self.body
    if params[:context_size].present?
      context_size = params[:context_size].to_i
      prev = {
        :begin => (span[:begin] < context_size)? 0 : span[:begin] - context_size,
        :end => span[:begin]
      }
      post = {
        :begin => span[:end],
        :end => (body.length - span[:end] < context_size)? body.length : span[:end] + context_size
      }
      prev_text = body[prev[:begin]...prev[:end]]
      post_text = body[post[:begin]...post[:end]]
    end
    return [prev_text, body[span[:begin]...span[:end]], post_text]
  end

  def span_url(span)
    if self.has_divs?
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_span_show_url(self.sourcedb, self.sourceid, self.serial, span[:begin], span[:end])
    else
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_span_show_url(self.sourcedb, self.sourceid, span[:begin], span[:end])
    end
  end

  def spans_index(project = nil)
    self.hdenotations(project).map{|d| {id:d[:id], span:d[:span], obj:self.span_url(d[:span])}}.uniq{|d| d[:span]}
  end


  def text(params)
    prev_text, span, next_text = self.span(params)
    [prev_text, span, next_text].compact.join('') 
  end

  def set_ascii_body
    self.original_body = self.body
    self.body = get_ascii_text(self.body)
  end

  def to_csv(params)
    focus, left, right = self.span(params) 
    CSV.generate(col_sep: "\t") do |csv|
      if params[:context_size].present?
        headers = %w(left focus right)
        values = [left, focus, right]
      else
        headers = %w(focus)
        values = [focus]
      end
      csv << headers
      csv << values 
    end
  end  
  
  def highlight_span(span)
    begin_pos = span[:begin].to_i
    end_pos = span[:end].to_i
    prev_text = self.body[0...begin_pos]
    spans = self.body[begin_pos...end_pos]
    next_text = self.body[end_pos..self.body.length]
    "#{prev_text}<span class='highlight'>#{spans}</span>#{next_text}"   
  end
  
  # TODO: to take care of associate projects
  # the first argument, project, may be a project or an array of projects.
  def get_denotations(project = nil, span = nil)
    denotations = if project.present?
      if project.respond_to?(:each)
        self.denotations.where('denotations.project_id IN (?)', project.map{|p| p.id})
      else
        self.denotations.where('denotations.project_id = ?', project.id)
      end
    else
      self.denotations
    end
    self.text_aligner = TextAlignment::TextAlignment.new(self.original_body, self.body, TextAlignment::MAPPINGS) unless self.original_body.nil?
    self.text_aligner.transform_denotations!(denotations) if self.text_aligner.present?
    denotations.select!{|d| d.begin >= span[:begin] && d.end <= span[:end]} if span.present?
    denotations.sort!{|d1, d2| d1.begin <=> d2.begin || (d2.end <=> d1.end)}
  end

  # the first argument, project, may be a project or an array of projects.
  def hdenotations(project = nil, span = nil)
    self.get_denotations(project, span).map{|d| d.get_hash}
  end
  
  # the first argument, project, may be a project or an array of projects.
  def denotations_in_tracks(project = nil, span = nil)
    _projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    _projects.inject([]){|t, p| t << {project:p.name, denotations:self.hdenotations(p, span)}}
  end

  def get_denotations_count(project = nil, span = nil)
    if project.nil? && span.nil?
      self.denotations_count
    elsif span.nil?
      self.denotations.where("denotations.project_id = ?", project.id).count
    else
      self.get_denotations(project, span).size
    end
  end

  def annotations_count(project = nil, span = nil)
    if project.nil? && span.nil?
      self.denotations.count + self.subcatrels.count + self.catmods.count + self.subcatrelmods.count
    else
      hdenotations = self.hdenotations(project, span)
      ids =  hdenotations.collect{|d| d[:id]}
      hrelations = self.hrelations(project, ids)
      ids += hrelations.collect{|d| d[:id]}
      hmodifications = self.hmodifications(project, ids)
      hdenotations.size + hrelations.size + hmodifications.size
    end
  end

  # the first argument, project, may be a project or an array of projects.
  def hrelations(project = nil, base_ids = nil)
    projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    relations = self.subcatrels.from_projects(projects)
    hrelations = relations.collect {|ra| ra.get_hash}
    hrelations.select!{|r| base_ids.include?(r[:subj]) && base_ids.include?(r[:obj])} unless base_ids.nil?
    hrelations.sort!{|r1, r2| r1[:id] <=> r2[:id]}
  end
  
  def hmodifications(project = nil, base_ids = nil)
    projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    modifications = self.catmods.from_projects(projects) + self.subcatrelmods.from_projects(projects)
    hmodifications = modifications.collect {|m| m.get_hash}
    hmodifications.select!{|m| base_ids.include?(m[:obj])} unless base_ids.nil?
    hmodifications.sort!{|m1, m2| m1[:id] <=> m2[:id]}
  end

  def hannotations(project = nil, span = nil, context_size = nil)
    annotations = {}

    annotations[:target] = if self.has_divs?
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_show_path(self.sourcedb, self.sourceid, self.serial, :only_path => false)
    else
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_path(self.sourcedb, self.sourceid, :only_path => false)
    end

    annotations[:sourcedb] = self.sourcedb
    annotations[:sourceid] = self.sourceid
    annotations[:divid] = self.serial if self.has_divs?

    annotations[:text] = if span.present?
      self.body[span[:begin]...span[:end]]
    else
      self.body
    end

    if project.present? && !project.respond_to?(:each)
      annotations[:project] = project.name
      annotations[:denotations] = self.hdenotations(project, span)
      annotations[:denotations].each{|d| d[:span][:begin] -= span[:begin]; d[:span][:end] -= span[:begin]} if span.present?
      ids = annotations[:denotations].collect{|d| d[:id]}
      annotations[:relations] = self.hrelations(project, ids)
      ids += annotations[:relations].collect{|r| r[:id]}
      annotations[:modifications] = self.hmodifications(project, ids)
      annotations[:namespaces] = project.namespaces
      annotations.select!{|k, v| v.present?}
    else
      projects = project.present? ? project : self.projects
      annotations[:tracks] = projects.inject([]) do |tracks, project|
        hdenotations = self.hdenotations(project, span)
        hdenotations.each{|d| d[:span][:begin] -= span[:begin]; d[:span][:end] -= span[:begin]} if span.present?
        ids =  hdenotations.collect{|d| d[:id]}
        hrelations = self.hrelations(project, ids)
        ids += hrelations.collect{|d| d[:id]}
        hmodifications = self.hmodifications(project, ids)
        track = {project:project.name, denotations:hdenotations, relations:hrelations, modificationss:hmodifications, namespaces:project.namespaces}
        track.select!{|k, v| v.present?}
        if track[:denotations].present?
          tracks << track
        else
          tracks
        end
      end
    end

    annotations
  end

  def destroy_project_annotations(project)
    return if project.nil?

    denotations = self.denotations.where(project_id: project.id)
    ActiveRecord::Base.transaction do
      denotations.destroy_all
    end
  end

  def projects_within_span(span)
    self.get_denotations(nil, span).collect{|d| d.project}.uniq.compact
  end

  def spans_projects(params)
    self_denotations = self.denotations
    if self_denotations.present?
      self_denotations.within_span({:begin => params[:begin], :end => params[:end]}).collect{|denotation| denotation.project}.uniq.compact
    end  
  end

  # to_be_deprecated in favor to to_hash below
  def json_hash
    json_hash = {
      id: id,
      text: body.gsub(/[\r\n]/, ""),
      sourcedb: sourcedb,
      sourceid: sourceid,
      section: section,
      source_url: source
    }
    # if has_divs?
      json_hash[:divid] = serial
    # end
    return json_hash
  end
  
  def to_hash
    {
      text: body.nil? ? nil : body.gsub(/[\r\n]/, ''),
      sourcedb: sourcedb,
      sourceid: sourceid,
      divid: serial,
      section: section,
      source_url: source
    }
  end
  
  def to_list_hash(doc_type)
    hash = {
      sourcedb: sourcedb,
      sourceid: sourceid,
    }
    # switch url or div_url
    case doc_type
    when 'doc'
      hash[:url] = Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(self.sourcedb, self.sourceid)
    when 'div'
      hash[:divid] = serial
      hash[:section] = section
      hash[:url] = Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_index_url(self.sourcedb, self.sourceid)
    end
    return hash
  end

  def self.to_tsv(docs, doc_type)
    headers = docs.first.to_list_hash(doc_type).keys
    tsv = CSV.generate(col_sep:"\t") do |csv|
      # headers
      csv << headers
      docs.each do |doc|
        doc_values = Array.new
        headers.each do |key|
          doc_values << doc.to_list_hash(doc_type)[key]
        end
        csv << doc_values
      end
    end
    return tsv
  end

  def self.sql_find(params, current_user, project)
    if params[:sql].present?
      current_user_id = current_user.present? ? current_user.id : nil
      sanitized_sql = sanitize_sql(params[:sql])
      results = self.connection.execute(sanitized_sql)
      if results.present?
        ids = results.collect{| result | result['id']}
        if project.present?
          # within project
          docs = self.accessible_projects(current_user_id).projects_docs([project.id]).sql(ids)
        else
          # within accessible projects
          docs = self.accessible_projects(current_user_id).sql(ids)
        end
      end       
    end
  end
  
  def updatable_for?(current_user)
    if current_user.present?
      (current_user.root? || created_by?(current_user))
    else
      false
    end
  end

  def created_by?(current_user)
    sourcedb.include?(':') && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
  end
  
  def self.create_doc(doc_hash, attributes = {})
    if divs_hash.present?
      divs = Array.new
      divs_hash.each_with_index do |div_hash, i|
        doc = Doc.new(
          {
            :body     => doc_hash[:body],
            :section  => doc_hash[:heading],
            :source   => attributes[:source_url],
            :sourcedb => attributes[:sourcedb],
            :sourceid => attributes[:sourceid],
            :serial   => i
          }
        )
        divs << doc if doc.save
      end
    end
    return divs
  end


  def self.create_divs(divs_hash, attributes = {})
    if divs_hash.present?
      divs = Array.new
      divs_hash.each_with_index do |div_hash, i|
        doc = Doc.new(
          {
            :body     => div_hash[:body],
            :section  => div_hash[:heading],
            :source   => attributes[:source_url],
            :sourcedb => attributes[:sourcedb],
            :sourceid => attributes[:sourceid],
            :serial   => i
          }
        )
        divs << doc if doc.save
      end
    end
    return divs
  end

  def self.has_divs?(sourcedb, sourceid)
    self.same_sourcedb_sourceid(sourcedb, sourceid).size > 1
  end

  def has_divs?
    self.class.same_sourcedb_sourceid(sourcedb, sourceid).size > 1
  end

  def self.get_div_ids(sourcedb, sourceid)
    self.same_sourcedb_sourceid(sourcedb, sourceid).select('serial').to_a.map{|d| d.serial}
  end

  def attach_sourcedb_suffix
    if sourcedb.include?(':') == false && username.present?
      self.sourcedb = "#{sourcedb}#{UserSourcedbSeparator}#{username}"
    end
  end

  def expire_page_cache
    ActionController::Base.new.expire_fragment('sourcedbs')
  end

  # before destroy
  def decrement_docs_counter
    if self.projects.present?
      self.projects.each do |project|
        project.decrement_docs_counter(self)
      end
    end
  end

  def get_annotations (span = nil, project = nil, options = {})
    hdenotations = self.hdenotations(project, span)
    hrelations = self.hrelations(project, span)
    hmodifications = self.hmodifications(project, span)
    text = self.body
    if (options[:encoding] == 'ascii')
      asciitext = get_ascii_text (text)
      text_alignment = TextAlignment::TextAlignment.new(text, asciitext)
      hdenotations = text_alignment.transform_denotations(hdenotations)
      text = asciitext
    end

    if (options[:discontinuous_annotation] == 'bag')
      # TODO: convert to hash representation
      hdenotations, hrelations = bag_denotations(hdenotations, hrelations)
    end

    annotations = Hash.new
    
    # project
    annotations[:project] = project[:name] if project.present?

    # doc
    annotations[:sourcedb] = self.sourcedb
    annotations[:sourceid] = self.sourceid
    annotations[:divid] = self.serial
    annotations[:section] = self.section
    annotations[:text] = text
    # doc.relational_models
    annotations[:denotations] = hdenotations if hdenotations
    annotations[:relations] = hrelations if hrelations
    annotations[:modifications] = hmodifications if hmodifications
    annotations
  end
end
