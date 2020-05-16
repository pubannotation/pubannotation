class Doc < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  LIST_MAX_SIZE = 50

  settings index: {
    analysis: {
      analyzer: {
        standard_normalization: {
          tokenizer: :standard,
          filter: [:standard, :lowercase, :stop, :asciifolding, :snowball]
        }
      }
    }
  } do
    mappings do
      indexes :sourcedb, type: :keyword
      indexes :sourceid, type: :keyword
      indexes :serial,   type: :integer
      indexes :body,     type: :text,  analyzer: :standard_normalization, index_options: :offsets

      # indexes :docs_projects, type: 'nested' do
      indexes :docs_projects do
        indexes :doc_id
        indexes :project_id
      end

      indexes :projects do
        indexes :id, type: :integer
      end
    end
  end

  SOURCEDBS = ["PubMed", "PMC", "FirstAuthors", 'GrayAnatomy', 'CORD-19']

  def as_indexed_json(options={})
    as_json(
      only: [:id, :sourcedb, :sourceid, :serial, :body],
      include: { projects: {only: :id} }  
    )
  end
  
  def self.search_docs(attributes = {})
    filter_condition = []
    filter_condition << {term: {'serial' => 0}} unless attributes[:sourceid].present?
    filter_condition << {term: {'projects.id' => attributes[:project_id]}} if attributes[:project_id].present?
    filter_condition << {term: {'sourcedb' => attributes[:sourcedb]}} if attributes[:sourcedb].present?
    filter_condition << {term: {'sourceid' => attributes[:sourceid]}} if attributes[:sourceid].present?

    filter_phrase = {
      bool: {
        must: filter_condition
      }
    }

    docs = search(
      query: {
        bool: {
          must: {
            match: {
              body: {
                query: attributes[:body]
              }
            }
          },
          filter: filter_phrase
        }
      },
      highlight: {
        fields: {
          body: {}
        }
      }
    ).page(attributes[:page]).per(attributes[:per])

    return docs
  end

  UserSourcedbSeparator = '@'
  after_save :expire_page_cache
  after_destroy :expire_page_cache
  # before_validation :attach_sourcedb_suffix
  include ApplicationHelper

  attr_accessor :username, :original_body, :text_aligner
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid, :username
  has_many :denotations, dependent: :destroy

  has_many :subcatrels, class_name: 'Relation', :through => :denotations, :source => :subrels

  has_many :denotation_attributes, class_name: 'Attrivute', :through => :denotations, :source => :attrivutes

  has_many :catmods, class_name: 'Modification', :through => :denotations, :source => :modifications
  has_many :subcatrelmods, class_name: 'Modification', :through => :subcatrels, :source => :modifications

  has_many :project_docs, dependent: :destroy
  has_many :projects, through: :project_docs,
    :after_add => [:increment_docs_projects_counter, :update_es_doc],
    :after_remove => [:decrement_docs_projects_counter, :update_es_doc]

  validates :body,     :presence => true
  validates :sourcedb, :presence => true
  validates :sourceid, :presence => true
  validates :serial,   :presence => true
  validates_uniqueness_of :serial, scope: [:sourcedb, :sourceid]
  
  scope :pmdocs, where(:sourcedb => 'PubMed')
  scope :pmcdocs, where(:sourcedb => 'PMC', :serial => 0)
  scope :project_name, lambda{|project_name|
    {:joins => :projects,
      :conditions => ['projects.name =?', project_name]
    }
  }

  scope :simple_paginate, -> (page, per = 10) {
    page = page.nil? ? 1 : page.to_i
    offset = (page - 1) * per
    offset(offset).limit(per)
  }

  scope :relations_num,
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
  #DefaultSort = [['sourceid', 'ASC']]

  def self.graph_uri
    "http://pubannotation.org/docs"
  end

  def graph_uri
    has_divs? ?
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_show_path(sourcedb, sourceid, serial, only_path: false) :
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_path(sourcedb, sourceid, only_path: false)
  end

  def last_indexed_at(endpoint = nil)
    if endpoint.nil?
      endpoint = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
    end
    db = Rails.application.config.ep_database
    result = endpoint.query(db, "select ?o where {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?o}")
    begin
      DateTime.parse(result.body["results"]["bindings"].first["o"]["value"])
    rescue
      nil
    end
  end

  def update_es_doc(project)
    self.__elasticsearch__.index_document
  end

  def update_annotations_updated_at(project)
    project.update_attribute(:annotations_updated_at, DateTime.now)
  end

  def increment_docs_projects_counter(project)
    Doc.increment_counter(:projects_num, self.id)
  end

  def decrement_docs_projects_counter(project)
    Doc.decrement_counter(:projects_num, self.id)
    self.reload
  end

  def descriptor
    descriptor  = self.sourcedb + ':' + self.sourceid
    descriptor += '-' + self.serial.to_s if self.has_divs?
    descriptor
  end

  def filename
    if has_divs?
      "#{sourcedb}-#{sourceid}-#{serial}-#{section.sub(/\.$/, '').gsub(' ', '_')}"
    else
      "#{sourcedb}-#{sourceid}"
    end
  end

  def self.get_doc(docspec)
    if docspec[:sourcedb].present? && docspec[:sourceid].present?
      Doc.find_by_sourcedb_and_sourceid_and_serial(docspec[:sourcedb], docspec[:sourceid], docspec[:divid].present? ? docspec[:divid] : 0)
    else
      nil
    end
  end

  def self.get_divs(docspec)
    if docspec[:sourcedb].present? && docspec[:sourceid].present?
      if docspec[:div_id].present?
        Doc.find_all_by_sourcedb_and_sourceid_and_serial(docspec[:sourcedb], docspec[:sourceid], docspec[:divid])
      else
        Doc.find_all_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
      end
    else
      []
    end
  end

  def self.exist?(docspec)
    !self.get_doc(docspec).nil?
  end

  def self.sequence_docs(sourcedb, sourceids)
    raise ArgumentError, "sourcedb is empty" unless sourcedb.present?
    raise ArgumentError, "sourceids is empty" unless sourceids.present?

    begin
      sequencer = Sequencer.find(sourcedb)
    rescue ActiveRecord::ActiveRecordError => e
      raise ActiveRecord::ActiveRecordError, "These documents could not be found and sourced: [#{sourcedb}] #{sourceids.join(', ')}."
    end
    raise "These documents could not be found and sourced: [#{sourcedb}] #{sourceids.join(', ')}." unless sequencer.present?

    result = sequencer.get_docs(sourceids)

    docs = if result[:docs].present?
      result[:docs].map do |doc|
        Doc.new(
          {
            section: doc[:section],
            body: doc[:text],
            sourcedb: doc[:sourcedb],
            sourceid: doc[:sourceid],
            serial: doc[:divid].to_i,
            source: doc[:source_url]
          }
        )
      end
    else
      []
    end

    docs_valid = docs.select{|doc| doc.valid?}
    unless docs_valid.empty?
      r = Doc.import docs_valid
      raise RuntimeError, "documents import error" unless r.failed_instances.empty?
    end

    docs_invalid = docs - docs_valid

    messages = result[:messages]

    docs_invalid.each do |doc|
      messages << {sourcedb:doc.sourcedb, sourceid:doc.sourceid, body:"Failed to save the document."}
    end

    [docs_valid, messages]
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

  def self.is_mdoc_sourcedb(sourcedb)
    ['PMC'].include?(sourcedb)
  end

  def revise(new_body)
    return [] if new_body == self.body

    _denotations = self.denotations
    messages = Annotation.align_denotations!(_denotations, self.body, new_body)
    self.body = new_body

    ActiveRecord::Base.transaction do
      save!
      _denotations.each{|d| d.save!}
    end

    messages
  end

  def self.uptodate(divs)
    sourcedb = divs[0].sourcedb
    sourceid = divs[0].sourceid
    new_divs = Object.const_get("DocSequencer#{sourcedb}").new(sourceid).divs
    raise RuntimeError, "The number of divs mismatch" unless new_divs.size == divs.size

    divs.sort!{|a, b| a.serial <=> b.serial}

    ActiveRecord::Base.transaction do
      divs.each_with_index{|div, i| div.revise(new_divs[i][:body])}
    end
  end

  def get_slices(max_size, span = nil)
    text = get_text(span)
    length = text.length
    if length > max_size
      slices = []
      _begin = 0
      while _begin + max_size < length
        subtext = text[_begin ... _begin + max_size]
        _end = subtext.rindex("\n")
        if _end.nil?
          raise RuntimeError, "Could not split the document."
        else
          _end += _begin
        end
        slices << {begin:_begin, end:_end}
        _begin = _end + 1
      end
      slices << {begin:_begin, end:length}
      unless span.nil?
        slices.each do |slice|
          slice[:begin] += span[:begin]
          slice[:end] += span[:begin]
        end
      end
      slices
    else
      span.nil? ? [nil] : [span]
    end
  end

  # returns relations count which belongs to project and doc
  def project_relations_num(project_id)
    count = Relation.project_relations_num(project_id, subcatrels)
  end
  
  # returns doc.relations count
  def relations_num
    subcatrels.size
  end
  
  def same_sourceid_denotations_num
    #denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
    #Denotation.select('doc_id').where('doc_id IN (?)', denotation_doc_ids).size
    Doc.where(:sourceid => self.sourceid).sum('denotations_num')
  end

  def same_sourceid_relations_num
    Doc.where(:sourceid => self.sourceid).sum('relations_num')
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
    focus_text = self.body[begin_pos...end_pos]
    next_text = self.body[end_pos..self.body.length]
    "<span class='context'>#{prev_text}</span><span class='highlight'>#{focus_text}</span><span class='context'>#{next_text}</span>"   
  end

  def get_annotation_ids(project, span = nil)
    dids = if span.nil?
      denotations.where(project_id: project.id).pluck(:hid)
    else
      denotations.where(["project_id = ? AND begin >= ? AND denotations.end <= ?", project.id, span[:begin], span[:end]]).pluck(:hid)
    end

    return [] if dids.empty?

    hrelations = hrelations(project, dids)
    rids = hrelations.collect{|r| r[:id]}

    hattributes = hattributes(project, dids)
    aids = hattributes.collect{|a| a[:id]}

    hmodifications = hmodifications(project, dids + rids)
    mids = hmodifications.collect{|m| m[:id]}

    dids + rids + aids + mids
  end

  # TODO: to take care of associate projects
  # the first argument, project, may be a project or an array of projects.
  def get_denotations(project = nil, span = nil, context_size = nil)
    _denotations = if project.present?
      if project.respond_to?(:each)
        denotations.where('denotations.project_id IN (?)', project.map{|p| p.id})
      else
        denotations.where(:'denotations.project_id' => project.id)
      end
    else
      denotations
    end

    unless original_body.nil?
      text_aligner = TextAlignment::TextAlignment.new(original_body, body, TextAlignment::MAPPINGS)
      text_aligner.transform_denotations!(_denotations) if text_aligner.present?
    end

    if span.present?
      _denotations.select!{|d| d.begin >= span[:begin] && d.end <= span[:end]}

      b = span[:begin]
      context_size ||= 0
      if context_size > 0
        b -= context_size
        b = 0 if b < 0
      end
      _denotations.each{|d| d.begin -= b; d.end -= b}
    end

    _denotations.sort!{|d1, d2| d1.begin <=> d2.begin || (d2.end <=> d1.end)}
  end

  # the first argument, project, may be a project or an array of projects.
  def hdenotations(project = nil, span = nil, context_size = nil)
    self.get_denotations(project, span, context_size).map{|d| d.get_hash}
  end

  def hdenotations_all
    annotations = {}
    annotations[:denotations] = hdenotations
    annotations[:target] = if has_divs?
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_show_path(sourcedb, sourceid, serial, :only_path => false)
    else
      Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_path(sourcedb, sourceid, :only_path => false)
    end
    annotations[:sourcedb] = sourcedb
    annotations[:sourceid] = sourceid
    annotations[:divid] = serial if has_divs?
    annotations[:text] = body
    annotations
  end

  # the first argument, project, may be a project or an array of projects.
  def denotations_in_tracks(project = nil, span = nil)
    _projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    _projects.inject([]){|t, p| t << {project:p.name, denotations:self.hdenotations(p, span)}}
  end

  def get_denotations_num(project = nil, span = nil)
    if project.nil? && span.nil?
      denotations_num
    elsif span.nil?
      ProjectDoc.where(project_id:project.id, doc_id:id).pluck(:denotations_num).first
    else
      get_denotations(project, span).count
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
  
  # the first argument, project, may be a project or an array of projects.
  def hattributes(project = nil, base_ids = nil)
    projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    attrivutes = self.denotation_attributes.from_projects(projects)
    hattrivutes = attrivutes.collect {|a| a.get_hash}
    hattrivutes.select!{|a| base_ids.include?(a[:subj])} unless base_ids.nil?
    hattrivutes.sort!{|a1, a2| a1[:id] <=> a2[:id]}
  end

  def hmodifications(project = nil, base_ids = nil)
    projects = project.present? ? (project.respond_to?(:each) ? project : [project]) : self.projects
    modifications = self.catmods.from_projects(projects) + self.subcatrelmods.from_projects(projects)
    hmodifications = modifications.collect {|m| m.get_hash}
    hmodifications.select!{|m| base_ids.include?(m[:obj])} unless base_ids.nil?
    hmodifications.sort!{|m1, m2| m1[:id] <=> m2[:id]}
  end

  def get_text(span = nil, context_size = nil)
    if span.present?
      b, e = 0, 0
      context_size ||= 0
      b = span[:begin] - context_size
      e = span[:end] + context_size
      b = 0 if b < 0
      e = body.length if e > body.length
      body[b...e]
    else
      body
    end
  end

  def hannotations(project = nil, span = nil, context_size = nil, options = nil)
    annotations = {
      target: graph_uri,
      sourcedb: sourcedb,
      sourceid: sourceid,
      text: get_text(span, context_size)
    }
    annotations[:divid] = serial if has_divs?

    if project.present? && !project.respond_to?(:each)
      annotations.merge!(get_project_annotations(project, span, context_size, options))
    else
      projects = project.present? ? project : self.projects
      annotations[:tracks] = projects.inject([]) do |tracks, project|
        track = get_project_annotations(project, span, context_size, options)
        if track[:denotations].present?
          tracks << track
        else
          tracks
        end
      end
    end

    annotations
  end

  def get_project_annotations(project, span = nil, context_size = nil, options = {})
    hdenotations = hdenotations(project, span, context_size)
    ids =  hdenotations.collect{|d| d[:id]}
    hrelations = hrelations(project, ids)
    hattributes = hattributes(project, ids)
    ids += hrelations.collect{|d| d[:id]}
    hmodifications = hmodifications(project, ids)

    options ||= {}
    if options[:discontinuous_span] == :bag
      hdenotations, hrelations = Annotation.bag_denotations(hdenotations, hrelations)
    end

    {project:project.name, denotations:hdenotations, relations:hrelations, attributes:hattributes, modifications:hmodifications, namespaces:project.namespaces}.select{|k, v| v.present?}
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

  def hdoc
    {
      text: body,
      sourcedb: sourcedb,
      sourceid: sourceid,
      divid: serial,
    }
  end

  def to_hash
    {
      text: body.nil? ? nil : body,
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
      sourceid: sourceid
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

  def self.hash_to_tsv(docs)
    headers = docs.first.keys
    tsv = CSV.generate(col_sep:"\t") do |csv|
      # headers
      csv << headers
      docs.each do |doc|
        csv << doc.values
      end
    end
    return tsv
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

  def self.sourcedb_public?(sourcedb)
    !sourcedb.include?(UserSourcedbSeparator)
  end

  def self.sourcedb_mine?(sourcedb, current_user)
    current_user.present? && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
  end

  def created_by?(current_user)
    sourcedb.include?(':') && sourcedb.include?("#{UserSourcedbSeparator}#{current_user.username}")
  end
  
  def self.has_divs?(sourcedb, sourceid)
    Doc.where(sourcedb:sourcedb, sourceid:sourceid, serial:1).exists?
  end

  def has_divs?
    Doc.where(sourcedb:sourcedb, sourceid:sourceid, serial:1).exists?
  end

  def self.get_div_ids(sourcedb, sourceid)
    self.same_sourcedb_sourceid(sourcedb, sourceid).select('serial').to_a.map{|d| d.serial}
  end

  def self.hdoc_normalize!(hdoc, current_user, no_personalize = false)
    raise RuntimeError, "You have to be logged in to create a document." unless current_user.present?

    unless hdoc[:body].present?
      if hdoc[:text].present?
        hdoc[:body] = hdoc[:text]
      else
        raise ArgumentError, "Text is missing."
      end
    end

    hdoc.delete(:text) if hdoc[:text].present?

    raise ArgumentError, "Text is missing." unless hdoc[:body].present?

    if no_personalize
      raise ArgumentError, "sourcedb is missing." unless hdoc[:sourcedb].present?
    else
      # personalize the sourcedb unless no_personalize
      if hdoc[:sourcedb].present?
        if hdoc[:sourcedb].include?(Doc::UserSourcedbSeparator)
          parts = hdoc[:sourcedb].split(Doc::UserSourcedbSeparator)
          raise ArgumentError, "'#{Doc::UserSourcedbSeparator}' is a special character reserved for separation of the username from a personal sourcedb name." unless parts.length == 2
          raise ArgumentError, "'#{part[1]}' is not your username." unless parts[1] == current_user.username
        else
          hdoc[:sourcedb] += UserSourcedbSeparator + current_user.username
        end
      else
        hdoc[:sourcedb] = UserSourcedbSeparator + current_user.username
      end
    end

    # sourceid control
    unless hdoc[:sourceid].present?
      last_id = Doc.where(sourcedb: hdoc[:sourcedb]).pluck(:sourceid).max_by{|i| i.to_i}
      hdoc[:sourceid] = last_id.nil? ? '1' : last_id.next
    end

    hdoc.merge(serial:0)
  end

  def attach_sourcedb_suffix
    if sourcedb.include?(UserSourcedbSeparator) == false && username.present?
      self.sourcedb = "#{sourcedb}#{UserSourcedbSeparator}#{username}"
    end
  end

  def self.count_per_sourcedb(current_user)
    docs_count_per_sourcedb = Doc.where("serial = ?", 0).group(:sourcedb).count
    if current_user
      docs_count_per_sourcedb.delete_if do |sourcedb, doc_count|
        sourcedb.include?(Doc::UserSourcedbSeparator) && sourcedb.split(Doc::UserSourcedbSeparator)[1] != current_user.username
      end
    else
      docs_count_per_sourcedb.delete_if{|sourcedb, doc_count| sourcedb.include?(Doc::UserSourcedbSeparator)}
    end
    docs_count_per_sourcedb
  end

  def self.docs_count(current_user)
    docs_count_per_sourcedb = Doc.count_per_sourcedb(current_user)
    docs_count_per_sourcedb.values.inject(0){|sum, v| sum + v}
  end

  def expire_page_cache
    ActionController::Base.new.expire_fragment('sourcedb_counts')
    ActionController::Base.new.expire_fragment('docs_count')
  end

  def self.dummy(repeat_times)
    repeat_times.times do |t|
      create({sourcedb: 'FFIK', body: "body is #{ t }", sourceid: t.to_s, serial: 0})
    end
  end

  def self.update_numbers
    Doc.all.each do |d|
      d.update_numbers
    end
  end

  def update_numbers
    # numbers of this doc
    connection.execute("update docs set denotations_num=#{denotations.count}, relations_num=#{subcatrels.count}, modifications_num=#{catmods.count + subcatrelmods.count} where id=#{id}")

    # numbers of each project_doc
    d_stat = denotations.group(:project_id).count
    r_stat = subcatrels.group("relations.project_id").count

    m_stat1 = catmods.group("modifications.project_id").count
    m_stat2 = subcatrelmods.group("modifications.project_id").count
    m_stat  = m_stat1.merge(m_stat2){|k,v1,v2| v1 + v2}

    pids = (d_stat.keys + r_stat.keys + m_stat.keys).uniq
    pids.each do |pid|
      d_num = d_stat[pid] || 0
      r_num = r_stat[pid] || 0
      m_num = m_stat[pid] || 0
      connection.execute("update project_docs set denotations_num=#{d_num}, relations_num=#{r_num}, modifications_num=#{m_num} where doc_id=#{id} and project_id=#{pid}")
    end
  end
end
