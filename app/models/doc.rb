class Doc < ActiveRecord::Base
  before_destroy :decrement_docs_counter
  include ApplicationHelper
  
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :denotations
  has_many :instances, :through => :denotations

  has_many :subcatrels, :class_name => 'Relation', :through => :denotations, :source => :subrels
  has_many :subinsrels, :class_name => 'Relation', :through => :instances, :source => :subrels
  #has_many :objcatrels, :class_name => 'Relation', :through => :denotations, :source => :objrels
  #has_many :objinsrels, :class_name => 'Relation', :through => :instances, :source => :objrels

  has_many :insmods, :class_name => 'Modification', :through => :instances, :source => :modifications
  has_many :subcatrelmods, :class_name => 'Modification', :through => :subcatrels, :source => :modifications
  has_many :subinsrelmods, :class_name => 'Modification', :through => :subinsrels, :source => :modifications

  has_and_belongs_to_many :projects
  
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
  
  scope :sql, lambda{|ids, current_user_id|
      where('docs.id IN(?)', ids).
      order('docs.id ASC')
  }
    
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
    count =   Relation.project_relations_count(project_id, subcatrels)
    count +=  Relation.project_relations_count(project_id, subinsrels)
  end
  
  # returns doc.relations count
  def relations_count
    subcatrels.size # + subinsrels.size
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
  
  def hdenotations(project, options = {})
    if options.present? && options[:spans].present?
      denotations = self.denotations.within_spans(options[:spans][:begin_pos], options[:spans][:end_pos])
    else
      if project.class == Project
        denotations = self.denotations.where("project_id = ?", project.id)
      else
        denotations = self.denotations.projects_denotations(project.project_ids)
      end
    end
    hdenotations = denotations.order('begin ASC').collect {|ca| ca.get_hash} if denotations.present?    
  end
  
  def hinstances(project, options = {})
    if options.present? && options[:spans].present?
      denotation_ids = self.denotations.within_spans(options[:spans][:begin_pos], options[:spans][:end_pos]).collect{|denotation| denotation.id}
      instances = Instance.where('obj_id IN (?)', denotation_ids)
    else
      if project.class == Project
        instances = self.instances.where("instances.project_id = ?", project.id)
      else
        instances = self.instances.where("instances.project_id IN (?)", project.project_ids)
      end
    end
    if instances.present?
      instances.sort! {|i1, i2| i1.hid[1..-1].to_i <=> i2.hid[1..-1].to_i}
      hinstances = instances.collect {|ia| ia.get_hash}
    end
  end
  
  def hrelations(project, options = {})
    if options.present? && options[:spans].present?
      denotation_ids = self.denotations.within_spans(options[:spans][:begin_pos], options[:spans][:end_pos]).collect{|denotation| denotation.id}
      relations = Relation.where(["subj_id IN(?) AND obj_id IN (?) AND subj_type = 'Denotation' AND obj_type = 'Denotation'", denotation_ids, denotation_ids])
    else
      if project.class == Project
        relations  = self.subcatrels.where("relations.project_id = ?", project.id)
        relations += self.subinsrels.where("relations.project_id = ?", project.id)
      else
        relations  = self.subcatrels.where("relations.project_id IN (?)", project.project_ids)
        relations += self.subinsrels.where("relations.project_id IN (?)", project.project_ids)
      end
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
      modifications = Modification.
        joins('INNER JOIN instances ON modifications.obj_id = instances.id')
        .where("modifications.obj_type = 'Instance' AND instances.obj_id IN (?)", denotation_ids)
    else
      if project.class == Project
        modifications = self.insmods.where("modifications.project_id = ?", project.id)
        modifications += self.subcatrelmods.where("modifications.project_id = ?", project.id)
        modifications += self.subinsrelmods.where("modifications.project_id = ?", project.id)
      else
        modifications = self.insmods.where("modifications.project_id IN (?)", project.project_ids)
        modifications += self.subcatrelmods.where("modifications.project_id IN (?)", project.project_ids)
        modifications += self.subinsrelmods.where("modifications.project_id IN (?)", project.project_ids)
      end
    end
    if modifications.present?
      modifications.sort! {|m1, m2| m1.hid[1..-1].to_i <=> m2.hid[1..-1].to_i}
      hmodifications = modifications.collect {|ma| ma.get_hash}
    end
  end
  
  def self.sql_find(params, current_user_id, project)
    if params[:sql].present?
      sanitized_sql = sanitize_sql(params[:sql])
      results = self.connection.execute(sanitized_sql)
      if results.present?
        ids = results.collect{| result | result['id']}
        if project.present?
          # within project
          docs = self.accessible_projects(current_user_id).projects_docs([project.id]).sql(ids, current_user_id)
        else
          # within accessible projects
          docs = self.accessible_projects(current_user_id).sql(ids, current_user_id)
        end
      end       
    end
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
