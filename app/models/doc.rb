class Doc < ActiveRecord::Base
  before_destroy :decrement_docs_counter
  include ApplicationHelper
  
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :denotations, :dependent => :destroy

  has_many :subcatrels, :class_name => 'Relation', :through => :denotations, :source => :subrels

  has_many :catmods, :class_name => 'Modification', :through => :denotations, :source => :modifications
  has_many :subcatrelmods, :class_name => 'Modification', :through => :subcatrels, :source => :modifications

  has_and_belongs_to_many :projects

  validates :body,     :presence => true
  validates :sourcedb, :presence => true
  validates :sourceid, :presence => true
  validates :serial,   :presence => true
  
  scope :pmdocs, where(:sourcedb => 'PubMed')
  scope :pmcdocs, where(:sourcedb => 'PMC', :serial => 0)
  scope :project_name, lambda{|project_name|
    {:joins => :projects,
     :conditions => ['projects.name =?', project_name]
    }
   }
  scope :denotations_count,
    joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id").
    group('docs.id').
    order("count(denotations.id) DESC")

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
    .group(:sourcedb).group(:sourceid).order(order_key_method)
  }
  
  scope :same_sourcedb_sourceid, lambda{|sourcedb, sourceid|
    where(['sourcedb = ? AND sourceid = ?', sourcedb, sourceid])
  }
  
  scope :source_dbs, where(['sourcedb IS NOT ?', nil])
  
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
  
  def spans(params)
    begin_pos = params[:begin].to_i
    end_pos = params[:end].to_i
    context_window = params[:context_window].to_i
    spans = self.body[begin_pos...end_pos]
    body = self.body
    if params[:context_window].present?
      prev_begin_pos = begin_pos - context_window
      prev_end_pos = begin_pos
      if prev_begin_pos < 0
        prev_begin_pos = 0
      end
      prev_text = body[prev_begin_pos...prev_end_pos] 
      next_begin_pos = end_pos
      next_end_pos = end_pos + context_window
      next_text = body[next_begin_pos...next_end_pos] 
      if params[:format] == 'txt'
        prev_text = "#{prev_text}\t" if prev_text.present?
        spans = "#{spans}\t" if next_text.present?
      end
    end
    if params[:encoding] == 'ascii'
      spans = get_ascii_text(spans)
      if params[:context_window].present?
        next_text = get_ascii_text(next_text)[0...context_window]
        ascii_prev_text = get_ascii_text(prev_text) 
        if context_window > ascii_prev_text.length
          context_window = ascii_prev_text.length
        end
        prev_text = ascii_prev_text[(context_window * -1)..-1]
      end
    end
    return [spans, prev_text, next_text]    
  end
  
  def spans_highlight(params)
    begin_pos = params[:begin].to_i
    end_pos = params[:end].to_i
    prev_text = self.body[0...begin_pos]
    spans = self.body[begin_pos...end_pos]
    next_text = self.body[end_pos..self.body.length]
    "#{prev_text}<span class='highlight'>#{spans}</span>#{next_text}"   
  end
  
  def hdenotations(project, options = {})
    if options.present? && options[:spans].present?
      denotations = self.denotations.where("project_id = ?", project.id).within_spans(options[:spans][:begin_pos], options[:spans][:end_pos])
    else
      if project.associate_projects.blank?
        denotations = self.denotations.where("project_id = ?", project.id)
      else
        denotations = self.denotations.projects_denotations(project.self_id_and_associate_project_ids)
      end
    end
    hdenotations = denotations.order('begin ASC').collect {|ca| ca.get_hash} if denotations.present?    
  end
  
  # return denotations group by project
  def project_denotations
    if self.denotations.present?
      denotations_by_project = self.denotations.group_by(&:project_id)
      denotations = Array.new
      denotations_by_project.each do |key, denotations_array|
        denotation_project = denotations_array[0].project
        denotations << {:project => denotation_project, :denotations => self.hdenotations(denotation_project)}
      end
      return denotations
    end
  end
  
  def hrelations(project, options = {})
    if options.present? && options[:spans].present?
      denotation_ids = self.denotations.within_spans(options[:spans][:begin_pos], options[:spans][:end_pos]).collect{|denotation| denotation.id}
      relations = Relation.where(["subj_id IN(?) AND obj_id IN (?) AND subj_type = 'Denotation' AND obj_type = 'Denotation'", denotation_ids, denotation_ids])
    else
      relations  = self.subcatrels.where("relations.project_id = ?", project.id)
    end
    if relations.present?
      relations.sort! {|r1, r2| r1.hid[1..-1].to_i <=> r2.hid[1..-1].to_i}
      hrelations = relations.collect {|ra| ra.get_hash}
    end
  end
  
  def hmodifications(project, options = {})
    if options.present? && options[:spans].present?
      self.denotations
      denotation_ids = self.denotations.within_spans(options[:spans][:begin_pos], options[:spans][:end_pos]).collect{|denotation| denotation.id}
      # SELECT "modifications".* FROM "modifications" INNER JOIN "instances" ON "modifications"."obj_id" = "instances"."id" AND "modifications"."obj_type" = 'Instance' WHERE "instances"."obj_id" = 1750
      # modifications = Modification.
      #   joins('INNER JOIN instances ON modifications.obj_id = instances.id')
      #   .where("modifications.obj_type = 'Instance' AND instances.obj_id IN (?)", denotation_ids)
      modifications = Modification.
        joins('INNER JOIN denotations ON modifications.obj_id = denotations.id')
        .where("modifications.obj_type = 'Denotation' AND denotations.id IN (?)", denotation_ids)
    else
      modifications  = self.catmods.where("modifications.project_id = ?", project.id)
      modifications += self.subcatrelmods.where("modifications.project_id = ?", project.id)
    end
    if modifications.present?
      modifications.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      hmodifications = modifications.collect {|ma| ma.get_hash}
    end
  end
  
  def spans_projects(params)
    self_denotations = self.denotations
    if self_denotations.present?
      self_denotations.within_spans(params[:begin], params[:end]).collect{|denotation| denotation.project}.uniq.compact
    end  
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
      if self.projects.present?
        project_users = Array.new
        self.projects.each do |project|
          project_users << project.user
          project_users = project_users | project.associate_maintainer_users if project.associate_maintainer_users.present?
        end
        project_users.include?(current_user)
      else
      # TODO When not belongs to project, how to detect updatable or not  ?
      end
    else
      false
    end
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
  
  def has_divs?
    Doc.same_sourcedb_sourceid(sourcedb, sourceid).size > 1
  end
      
  # before destroy
  def decrement_docs_counter
    if self.projects.present?
      self.projects.each do |project|
        project.decrement_docs_counter(self)
      end
    end
  end
end
