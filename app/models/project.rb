class Project < ActiveRecord::Base
  include AnnotationsHelper
  after_validation :user_presence
  belongs_to :user
  has_and_belongs_to_many :docs, :after_add => [:increment_docs_counter, :update_annotations_updated_at], :after_remove => [:decrement_docs_counter, :update_annotations_updated_at]
  has_and_belongs_to_many :pmdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PubMed'}
  has_and_belongs_to_many :pmcdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PMC', :serial => 0}
  
  # Project to Proejct associations
  # parent project => associate projects = @project.associate_projects
  has_and_belongs_to_many :associate_projects, 
    :foreign_key => 'project_id', 
    :association_foreign_key => 'associate_project_id', 
    :join_table => 'associate_projects_projects',
    :class_name => 'Project', 
    :before_add => :increment_pending_associate_projects_count,
    :after_add => [:increment_counters, :copy_associate_project_relational_models],
    :after_remove => :decrement_counters
    
  # associate projects => parent projects = @project.projects
  has_and_belongs_to_many :projects, 
    :foreign_key => 'associate_project_id',
    :association_foreign_key => 'project_id',
    :join_table => 'associate_projects_projects'

  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter, :annotations_zip_downloadable
  has_many :denotations, :dependent => :destroy
  has_many :relations, :dependent => :destroy
  has_many :modifications, :dependent => :destroy
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintainer_users, :through => :associate_maintainers, :source => :user, :class_name => 'User'
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}, uniqueness: true
  
  default_scope where(:type => nil).order('status ASC')

  scope :accessible, lambda{|current_user|
    if current_user.present?
      includes(:associate_maintainers).where('projects.accessibility = ? OR projects.user_id =? OR associate_maintainers.user_id =?', 1, current_user.id, current_user.id)
    else
      where(:accessibility => 1)
    end
  }

  scope :not_id_in, lambda{|project_ids|
    where('projects.id NOT IN (?)', project_ids)
  }

  scope :id_in, lambda{|project_ids|
    where('projects.id IN (?)', project_ids)
  }
  
  scope :name_in, lambda{|project_names|
    where('projects.name IN (?)', project_names) if project_names.present?
  }

  # scopes for order
  scope :order_pmdocs_count, 
    joins("LEFT OUTER JOIN docs_projects ON docs_projects.project_id = projects.id LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PubMed'").
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_pmcdocs_count, 
    joins("LEFT OUTER JOIN docs_projects ON docs_projects.project_id = projects.id LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PMC'").
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_denotations_count, 
    joins('LEFT OUTER JOIN denotations ON denotations.project_id = projects.id').
    group('projects.id').
    order("count(denotations.id) DESC")
    
  scope :order_relations_count,
    joins('LEFT OUTER JOIN relations ON relations.project_id = projects.id').
    group('projects.id').
    order('count(relations.id) DESC')
    
  scope :order_author,
    order('author ASC')
    
  scope :order_maintainer,
    joins('LEFT OUTER JOIN users ON users.id = projects.user_id').
    group('projects.id, users.username').
    order('users.username ASC')
  
  scope :order_association, lambda{|current_user|
    if current_user.present?
      joins("LEFT OUTER JOIN associate_maintainers ON projects.id = associate_maintainers.project_id AND associate_maintainers.user_id = #{current_user.id}").
      order("CASE WHEN projects.user_id = #{current_user.id} THEN 2 WHEN associate_maintainers.user_id = #{current_user.id} THEN 1 ELSE 0 END DESC")
    end
  }

  # default sort order 
  DefaultSortArray = [['name', 'ASC'], ['author', 'ASC'], ['users.username', 'ASC']]
  
  scope :sort_by_params, lambda{|sort_order|
      sort_order = sort_order.collect{|s| s.join(' ')}.join(', ')
      includes(:user).order(sort_order)
  }

  def status_text
   status_hash = {
     1 => I18n.t('activerecord.options.project.status.released'),
     2 => I18n.t('activerecord.options.project.status.beta'),
     3 => I18n.t('activerecord.options.project.status.developing'),
     4 => I18n.t('activerecord.options.project.status.testing')
   }

   status_hash[self.status]
  end
  
  def accessibility_text
   accessibility_hash = {
     1 => I18n.t('activerecord.options.project.accessibility.public'),
     2 => :Private
   }
   accessibility_hash[self.accessibility]
  end

  def self.order_by(projects, order, current_user)
    case order
    when 'pmdocs_count', 'pmcdocs_count', 'denotations_count', 'relations_count'
      projects.accessible(current_user).order("#{order} DESC")
    when 'author'
      projects.accessible(current_user).order_author
    when 'maintainer'
      projects.accessible(current_user).order_maintainer
    else
      # 'association' or nil
      projects.accessible(current_user).order_association(current_user)
    end    
  end
  
  # after_add doc
  def increment_docs_counter(doc)
    if doc.sourcedb == 'PMC' && doc.serial == 0
      counter_column = :pmcdocs_count
    elsif doc.sourcedb == 'PubMed'
      counter_column = :pmdocs_count
    end
    if counter_column
      Project.increment_counter(counter_column, self.id)
      if self.projects.present?
        self.projects.each do |project|
          Project.increment_counter(counter_column, project.id)
        end          
      end
    end
  end
  
  # after_remove doc
  def decrement_docs_counter(doc)
    if doc.sourcedb == 'PMC' && doc.serial == 0
      counter_column = :pmcdocs_count
    elsif doc.sourcedb == 'PubMed'
      counter_column = :pmdocs_count
    end
    if counter_column
      Project.decrement_counter(counter_column, self.id)
      if self.projects.present?
        self.projects.each do |project|
          Project.decrement_counter(counter_column, project.id)
        end          
      end          
    end          
  end          

  def update_annotations_updated_at(doc)
    self.update_attribute(:annotations_updated_at, DateTime.now)
  end

  def associate_maintainers_addable_for?(current_user)
    if self.new_record?
      true
    else
      current_user.root? == true || current_user == self.user
    end
  end
  
  def updatable_for?(current_user)
    current_user.root? == true || (current_user == self.user || self.associate_maintainer_users.include?(current_user))
  end

  def destroyable_for?(current_user)
    current_user.root? == true || current_user == user  
  end
  
  def association_for(current_user)
    if current_user.present?
      if current_user == self.user
        'M'
      elsif self.associate_maintainer_users.include?(current_user)
        'A'
      end
    end
  end
  
  def build_associate_maintainers(usernames)
    if usernames.present?
      users = User.where('username IN (?)', usernames)
      users = users.uniq if users.present?
      users.each do |user|
        self.associate_maintainers.build({:user_id => user.id})
      end
    end
  end
  
  def add_associate_projects(params_associate_projects, current_user)
    if params_associate_projects.present?
      associate_projects_names = Array.new
      params_associate_projects[:name].each do |index, name|
        associate_projects_names << name
        if params_associate_projects[:import].present? && params_associate_projects[:import][index]
          project = Project.includes(:associate_projects).find_by_name(name)
          associate_projects_accessible = project.associate_projects.accessible(current_user)
          # import associate projects which current user accessible 
          if associate_projects_accessible.present?
            associate_project_names = associate_projects_accessible.collect{|associate_project| associate_project.name}
            associate_projects_names = associate_projects_names | associate_project_names if associate_project_names.present?
          end
        end
      end
      associate_projects = Project.where('name IN (?) AND id NOT IN (?)', associate_projects_names.uniq, associate_project_and_project_ids)
      self.associate_projects << associate_projects
    end    
  end
  
  def associate_project_ids
    associate_project_ids = associate_projects.present? ? associate_projects.collect{|associate_project| associate_project.id} : []
    associate_project_ids.uniq
  end
  
  def self_id_and_associate_project_ids
    associate_project_ids << self.id if self.id.present?
  end
  
  def self_id_and_associate_project_and_project_ids
    associate_project_and_project_ids << self.id if self.id.present?
  end
  
  def project_ids
    project_ids = projects.present? ? projects.collect{|project| project.id} : []
    project_ids.uniq
  end
  
  def associate_project_and_project_ids
    if associate_project_ids.present? || project_ids.present?
      associate_project_ids | project_ids
    else
      [0]
    end
  end
  
  def associatable_project_ids(current_user)
    if self.new_record?
      associatable_projects = Project.accessible(current_user)
    else
      associatable_projects = Project.accessible(current_user).not_id_in(self.self_id_and_associate_project_and_project_ids)
    end
    associatable_projects.collect{|associatable_projects| associatable_projects.id}
  end
  
  # increment counters after add associate projects
  def increment_counters(associate_project)
    Project.update_counters self.id,
      :pmdocs_count => associate_project.pmdocs.count,
      :pmcdocs_count => associate_project.pmcdocs.count,
      :denotations_count => associate_project.denotations.count,
      :relations_count => associate_project.relations.count
  end 
  
  def increment_pending_associate_projects_count(associate_project)
    Project.increment_counter(:pending_associate_projects_count, self.id)
  end 
  
  def copy_associate_project_relational_models(associate_project)
    Project.decrement_counter(:pending_associate_projects_count, self.id)
    if associate_project.docs.present?
      copy_docs = associate_project.docs - self.docs
      copy_docs.each do |doc|
        # copy doc
        self.docs << doc
      end
    end
    
    if associate_project.denotations.present?
      # copy denotations
      associate_project.denotations.each do |denotation|
        same_denotation = self.denotations.where(
          {
            :hid => denotation.hid,
            :doc_id => denotation.doc_id,
            :begin => denotation.begin,
            :end => denotation.end,
            :obj => denotation.obj
          }
        )
        if same_denotation.blank?
          self.denotations << denotation.dup
        end
      end
    end
    
    if associate_project.relations.present?
      associate_project.relations.each do |relation|
        same_relation = self.relations.where({
          :hid => relation.hid,
          :subj_id => relation.subj_id,
          :subj_type => relation.subj_type,
          :obj_id => relation.obj_id,
          :obj_type => relation.obj_type,
          :pred => relation.pred
        })
        if same_relation.blank?
          self.relations << relation.dup
        end
      end
    end
  end
  handle_asynchronously :copy_associate_project_relational_models, :run_at => Proc.new { 1.minutes.from_now }
    
  # decrement counters after delete associate projects
  def decrement_counters(associate_project)
    Project.update_counters self.id, 
      :pmdocs_count => - associate_project.pmdocs.count,
      :pmcdocs_count => - associate_project.pmcdocs.count,
      :denotations_count => - associate_project.denotations.count,
      :relations_count => - associate_project.relations.count
  end
  
  def anncollection(encoding)
    anncollection = Array.new
    if self.docs.present?
      docs.each do |doc|
        # puts "#{doc.sourceid}:#{doc.serial} <======="
        # anncollection.push (get_annotations(self, doc, :encoding => encoding))
        anncollection.push (get_annotations_for_json(self, doc, :encoding => encoding))
      end
    end
    return anncollection
  end

  def json
    except_columns = %w(pmdocs_count pmcdocs_count pending_associate_projects_count user_id)
    to_json(except: except_columns, methods: :maintainer)
  end

  def docs_json_hash
    if docs.present?
      docs.collect{|doc| doc.json_hash}
    end
  end

  def maintainer
    user.present? ? user.username : ''
  end
  
  def annotations_zip_path
    "#{Denotation::ZIP_FILE_PATH}#{self.name}.zip"
  end
  
  def save_annotation_zip(options = {})
    require 'fileutils'
    unless Dir.exist?(Denotation::ZIP_FILE_PATH)
      FileUtils.mkdir_p(Denotation::ZIP_FILE_PATH)
    end
    anncollection = self.anncollection(options[:encoding])
    if anncollection.present?
      file_path = "#{Denotation::ZIP_FILE_PATH}#{self.name}.zip"
      file = File.new(file_path, 'w')
      Zip::ZipOutputStream.open(file.path) do |z|
        z.put_next_entry('project.json')
        z.print self.json
        z.put_next_entry('docs.json')
        z.print self.docs_json_hash.to_json
        anncollection.each do |ann|
          title = get_doc_info(ann[:target])
          title.sub!(/\.$/, '')
          title.gsub!(' ', '_')
          title += ".json" unless title.end_with?(".json")
          z.put_next_entry(title)
          z.print ann.to_json
        end
      end
      file.close   
    end  
  end 

  def self.params_from_json(json_file)
    project_attributes = JSON.parse(File.read(json_file))
    user = User.find_by_username(project_attributes['maintainer'])
    project_params = project_attributes.select{|key| Project.attr_accessible[:default].include?(key)}
  end

  def self.create_from_zip(zip_file, project_name, current_user)
    messages = Array.new
    errors = Array.new
    unless Dir.exist?(TempFilePath)
      FileUtils.mkdir_p(TempFilePath)
    end
    project_json_file = "#{TempFilePath}#{project_name}-project.json"
    docs_json_file = "#{TempFilePath}#{project_name}-docs.json"
    # open zip file
    Zip::ZipFile.open(zip_file) do |zipfile|
      zipfile.each do |file|
        file_name = file.name
        # extract project.json
        if file_name == 'project.json'
          file.extract(project_json_file) unless File.exist?(project_json_file)
        end
        # extract docs.json
        if file_name == 'docs.json'
          file.extract(docs_json_file) unless File.exist?(docs_json_file)
        end
      end
    end

    # create project if [project_name]-project.json exist
    project = nil
    if File.exist?(project_json_file)
      params_from_json = Project.params_from_json(project_json_file)
      File.unlink(project_json_file)
      project_params = params_from_json
      project = Project.new(project_params)
      project.user = current_user
      if project.valid?
        project.save
        created_project = project
        messages << I18n.t('controllers.shared.successfully_created', model: I18n.t('activerecord.models.project'))
      else
        errors << project.errors.full_messages.join('<br />')
        project = nil
      end
    end

    # create project.docs if [project_name]-project.json exist
    if File.exist?(docs_json_file)
      if project.present?
        num_created, num_added, num_failed = project.add_docs_from_json(File.read(docs_json_file))
        messages << I18n.t('controllers.docs.create_project_docs.created_to_document_set', num_created: num_created, project_name: project.name) if num_created > 0
        messages << I18n.t('controllers.docs.create_project_docs.added_to_document_set', num_added: num_added, project_name: project.name) if num_added > 0
        messages << I18n.t('controllers.docs.create_project_docs.failed_to_document_set', num_failed: num_failed, project_name: project.name) if num_failed > 0
      end
      File.unlink(docs_json_file) 
    end
    return [messages, errors]
  end

  def add_docs_from_json(json)
    json = JSON.parse(json)
    json = [json] if json.class == Hash
    num_created, num_added, num_failed = 0, 0, 0
    source_dbs = json.group_by{|doc| doc["source_db"]}
    if source_dbs.present?
      source_dbs.each do |source_db, docs_array|docs_array
        ids = docs_array.collect{|doc| doc["source_id"]}.join(",")
        num_created_t, num_added_t, num_failed_t = self.add_docs(ids, source_db, docs_array)
        num_created += num_created_t
        num_added += num_added_t
        num_failed += num_failed_t
      end
    end
    return [num_created, num_added, num_failed]   
  end
  
  def add_docs(ids, sourcedb, docs_array)
    num_created, num_added, num_failed = 0, 0, 0
    ids = ids.split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
    ids.each do |sourceid|
      divs = Doc.find_all_by_sourcedb_and_sourceid(sourcedb, sourceid)
      if divs.present?
        unless self.docs.include?(divs.first)
          self.docs << divs
          num_added += divs.size
        end
      else
        if sourcedb.include?(Doc::UserSourcedbSeparator)
          # when sourcedb is user generated
          divs = Array.new
          docs_array.each do |doc_array_params|
            # all of columns insert into database need to be included in this hash.
            mappings = {
              'text' => 'body', 
              'source_db' => 'sourcedb', 
              'source_id' => 'sourceid', 
              'section' => 'section', 
              'source_url' => 'source', 
              'div_id' => 'serial'
            }
            doc_params = Hash[doc_array_params.map{|key, value| [mappings[key], value]}].select{|key| key.present? && Doc.attr_accessible[:default].include?(key)}
            doc = Doc.new(doc_params) 
            if doc.valid?
              doc.save
              divs << doc
            else
              num_failed += 1
            end
          end
        else
          # when sourcedb is not user generated
          doc_sequence = Object.const_get("DocSequencer#{sourcedb}").new(sourceid)
          divs_hash = doc_sequence.divs
          divs = Doc.create_divs(divs_hash, :sourcedb => sourcedb, :sourceid => sourceid, :source_url => doc_sequence.source_url)
        end
        if divs
          self.docs << divs
          num_created += divs.size
        else
          num_failed += 1
        end
      end
    end  
    return [num_created, num_added, num_failed]   
  end

  def user_presence
    if user.blank?
      errors.add(:user_id, 'is blank') 
    end
  end
end
