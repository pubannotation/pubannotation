class Project < ActiveRecord::Base
  include ApplicationHelper
  include AnnotationsHelper
  DOWNLOADS_PATH = "/downloads/"

  before_validation :cleanup_namespaces
  after_validation :user_presence
  serialize :namespaces
  belongs_to :user
  has_many :collection_projects, dependent: :destroy
  has_many :collections, through: :collection_projects
  has_many :project_docs, dependent: :destroy
  has_many :docs, through: :project_docs
  has_many :queries

  has_many :evaluations, foreign_key: 'study_project_id'
  has_many :evaluatees, class_name: 'Evaluation', foreign_key: 'reference_project_id'

  attr_accessible :name, :description, :author, :anonymize, :license, :status, :accessibility, :reference,
                  :sample, :rdfwriter, :xmlwriter, :bionlpwriter,
                  :textae_config,
                  :annotations_zip_downloadable, :namespaces, :process,
                  :pmdocs_count, :pmcdocs_count, :denotations_num, :relations_num, :modifications_num, :annotations_count
  has_many :denotations, :dependent => :destroy, after_add: :update_updated_at
  has_many :relations, :dependent => :destroy, after_add: :update_updated_at
  has_many :attrivutes, :dependent => :destroy, after_add: :update_updated_at
  has_many :modifications, :dependent => :destroy, after_add: :update_updated_at
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintainer_users, :through => :associate_maintainers, :source => :user, :class_name => 'User'
  has_many :jobs, :dependent => :destroy
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9\-_]+\z/i

  def as_json(options={})
    options||={}
    json = {
      name: self.name,
      created_at: self.created_at,
      updated_at: self.updated_at
    }
    json[:maintainer] = self.user.username unless options[:except] && options[:except].include?(:maintainer)
    json[:author] = self.author if self.author.present?
    json[:license] = self.license if self.license.present?
    json[:namespaces] = self.namespaces if self.namespaces.present?
    json
  end

  default_scope where(:type => nil)

  scope :for_index, where('accessibility = 1 AND status < 3')
  scope :for_home, where('accessibility = 1 AND status < 4')

  scope :public_or_blind, where(accessibility: [1, 3])

  scope :accessible, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        where('accessibility = ? OR accessibility = ? OR user_id =?', 1, 3, current_user.id)
      end
    else
      where(accessibility: [1, 3])
    end
  }

  scope :annotations_accessible, -> (current_user){
    if current_user.present? 
      if current_user.root?
      else
        where(['projects.accessibility = 1 OR projects.user_id = ?', current_user.id])
      end
    else
      where(accessibility: 1)
    end
  }

  scope :editable, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        includes(:associate_maintainers).where('projects.user_id =? OR associate_maintainers.user_id =?', current_user.id, current_user.id)
      end
    else
      where(accessibility: 10)
    end
  }

  scope :mine, -> (current_user) {
    if current_user.present?
      includes(:associate_maintainers).where('projects.user_id = ? OR associate_maintainers.user_id = ?', current_user.id, current_user.id)
    end
  }

  def annotations_accessible?(current_user)
    if accessibility == 1
      true
    else
      if current_user && (current_user.root || current_user == user)
        true
      else
        false
      end
    end 
  end

  # scope for home#index
  scope :top_annotations_count,
    order('denotations_num DESC').order('projects.updated_at DESC').order('status ASC').limit(10)

  scope :top_recent,
    order('projects.updated_at DESC').order('annotations_count DESC').order('status ASC').limit(10)

  scope :not_id_in, lambda{|project_ids|
    where('projects.id NOT IN (?)', project_ids)
  }

  scope :id_in, lambda{|project_ids|
    where('projects.id IN (?)', project_ids)
  }
  
  scope :name_in, -> (project_names) {
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
    
  scope :order_denotations_num,
    joins('LEFT OUTER JOIN denotations ON denotations.project_id = projects.id').
    group('projects.id').
    order("count(denotations.id) DESC")
    
  scope :order_relations_num,
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

  # default sort order priority : left > right
  # DefaultSort = [['status', 'ASC'], ['projects.updated_at', 'DESC']]

  LicenseDefault = 'Creative Commons Attribution 3.0 Unported License'
  
  def public?
    accessibility == 1
  end

  def accessible?(current_user)
    accessibility == 1 || accessibility == 3 || (current_user.present? && (current_user == user || current_user.root?))
  end

  def editable?(current_user)
    current_user.present? && (current_user == user || current_user.root?)
  end

  def destroyable?(current_user)
    current_user == user || current_user.root?
  end

  def status_text
   status_hash = {
     1 => I18n.t('activerecord.options.project.status.released'),
     2 => I18n.t('activerecord.options.project.status.beta'),
     3 => I18n.t('activerecord.options.project.status.uploading'),
     8 => I18n.t('activerecord.options.project.status.developing'),
     9 => I18n.t('activerecord.options.project.status.testing')
   }

   status_hash[self.status]
  end
  
  def accessibility_text
   accessibility_hash = {
     1 => I18n.t('activerecord.options.project.accessibility.public'),
     2 => I18n.t('activerecord.options.project.accessibility.private'),
     3 => I18n.t('activerecord.options.project.accessibility.blind')
   }
   accessibility_hash[self.accessibility]
  end
  
  def process_text
   process_hash = {
     1 => I18n.t('activerecord.options.project.process.manual'),
     2 => I18n.t('activerecord.options.project.process.automatic')
   }
   process_hash[self.process]
  end

  def get_user(current_user)
    if anonymize == true
      if current_user.present? && (current_user.root? || current_user == user)
        user
      end
    else
      user
    end
  end

  def self.order_by(projects, order, current_user)
    case order
    when 'pmdocs_count', 'pmcdocs_count', 'denotations_num', 'relations_num'
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
  
  def associate_maintainers_addable_for?(current_user)
    if self.new_record?
      true
    else
      current_user.root? == true || current_user == self.user
    end
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
  
  def get_denotations_num(doc = nil, span = nil)
    if doc.nil?
      self.denotations_num
    else
      if span.nil?
        doc.denotations.where("denotations.project_id = ?", self.id).count
      else
        doc.hdenotations(self, span).length
      end
    end
  end

  def get_annotations_count(doc = nil, span = nil)
    if doc.nil?
      self.annotations_count
    else
      if span.nil?
        # begin from the doc because it should be faster.
        doc.denotations.where("denotations.project_id = ?", self.id).count + doc.subcatrels.where("relations.project_id = ?", self.id).count + doc.catmods.where("modifications.project_id = ?", self.id).count + doc.subcatrelmods.where("modifications.project_id = ?", self.id).count
      else
        hdenotations = doc.hdenotations(self, span)
        ids =  hdenotations.collect{|d| d[:id]}
        hrelations = doc.hrelations(self, ids)
        ids += hrelations.collect{|d| d[:id]}
        hmodifications = doc.hmodifications(self, ids)
        hdenotations.size + hrelations.size + hmodifications.size
      end
    end
  end

  def annotations_collection(encoding = nil)
    if self.docs.present?
      self.docs.collect{|doc| doc.set_ascii_body if encoding == 'ascii'; doc.hannotations(self)}
    else
      []
    end
  end

  def json
    except_columns = %w(pmdocs_count pmcdocs_count pending_associate_projects_count user_id)
    to_json(except: except_columns, methods: :maintainer)
  end

  def has_jobs?
    jobs.exists?
  end

  def has_running_jobs?
    jobs.each{|job| return true if job.running?}
    return false
  end

  def has_waiting_jobs?
    jobs.each{|job| return true if job.waiting?}
    return false
  end

  def has_doc?
    ProjectDoc.exists?(project_id: id)
  end

  def docs_list_hash
    docs.collect{|doc| doc.to_list_hash} if docs.present?
  end

  def maintainer
    user.present? ? user.username : ''
  end

  def downloads_system_path
    "#{Rails.root}/public#{Project::DOWNLOADS_PATH}" 
  end

  def annotations_zip_filename
    "#{self.name.gsub(' ', '_')}-annotations.zip"
  end

  def annotations_tgz_filename
    "#{self.name.gsub(' ', '_')}-annotations.tgz"
  end

  def annotations_zip_path
    "#{Project::DOWNLOADS_PATH}" + self.annotations_zip_filename
  end

  def annotations_tgz_path
    "#{Project::DOWNLOADS_PATH}" + self.annotations_tgz_filename
  end

  def annotations_zip_system_path
    self.downloads_system_path + self.annotations_zip_filename
  end

  def annotations_tgz_system_path
    self.downloads_system_path + self.annotations_tgz_filename
  end

  def create_annotations_zip(encoding = nil)
    require 'fileutils'

    annotations_collection = self.annotations_collection(encoding)

    FileUtils.mkdir_p(self.downloads_system_path) unless Dir.exist?(self.downloads_system_path)
    file = File.new(self.annotations_zip_system_path, 'w')
    Zip::ZipOutputStream.open(file.path) do |z|
      annotations_collection.each do |annotations|
        title = get_doc_info(annotations).sub(/\.$/, '').gsub(' ', '_')
        title += ".json" unless title.end_with?(".json")
        z.put_next_entry(title)
        z.print annotations.to_json
      end
    end
    file.close
  end 

  # incomplete
  def create_annotations_tgz(encoding = nil)
    require 'rubygems/package'
    require 'zlib'
    require 'fileutils'

    annotations_collection = self.annotations_collection(encoding)

    FileUtils.mkdir_p(downloads_system_path) unless Dir.exist?(downloads_system_path)
    Zlib::GzipWriter.open(annotations_tgz_system_path, Zlib::BEST_COMPRESSION) do |gz|
      Gem::Package::TarWriter.new(gz) do |tar|
        annotations_collection.each do |annotations|
          title = get_doc_info(annotations).sub(/\.$/, '').gsub(' ', '_')
          path  = self.name + '/' + title + ".json"
          stuff = annotations.to_json
          tar.add_file_simple(path, 0644, stuff.length){|t| t.write(stuff)}
        end
      end
    end
  end 

  def get_conversion (annotation, converter, identifier = nil)
    RestClient.post converter, annotation.to_json, :content_type => :json do |response, request, result|
      case response.code
      when 200
        response.force_encoding(Encoding::UTF_8)
      else
        raise RuntimeError, "Bad response from the converter"
      end
    end
  end

  def annotations_rdf_filename
    "#{self.name.gsub(' ', '_')}-annotations-rdf.zip"
  end

  def annotations_rdf_path
    "#{Project::DOWNLOADS_PATH}" + self.annotations_rdf_filename
  end

  def annotations_rdf_system_path
    self.downloads_system_path + self.annotations_rdf_filename
  end

  def create_rdf_zip (ttl)
    require 'fileutils'
    begin
      FileUtils.mkdir_p(self.downloads_system_path) unless Dir.exist?(self.downloads_system_path)
      file = File.new(self.annotations_rdf_system_path, 'w')
      Zip::ZipOutputStream.open(file.path) do |z|
        z.put_next_entry(self.name + '.ttl')
        z.print ttl
      end
      file.close
    end
  end

  def graph_uri
    Rails.application.routes.url_helpers.home_url + "projects/#{self.name}"
  end

  def docs_uri
    graph_uri + '/docs'
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

  def post_rdf_stardog(ttl, project_name = nil, initp = false)
    ttl_file = Tempfile.new("temporary.ttl")
    ttl_file.write(ttl)
    ttl_file.close

    graph_uri = project_name.nil? ? "http://pubannotation.org/docs" : "http://pubannotation.org/projects/#{project_name}"
    destination = "#{Pubann::Application.config.sparql_end_point}/sparql-graph-crud-auth?graph-uri=#{graph_uri}"
    cmd  = %[curl --digest --user #{Pubann::Application.config.sparql_end_point_auth} --verbose --url #{destination} -T #{ttl_file.path}]
    cmd += ' -X POST' unless initp

    puts cmd
    puts "+++"
    message, error, state = Open3.capture3(cmd)

    ttl_file.unlink

    raise RuntimeError, 'Could not store RDFized annotations' unless error.include?('201 Created') || error.include?('200 OK')
  end

  def post_rdf_virtuoso(ttl, project_name = nil, initp = false)
    require 'open3'

    ttl_file = Tempfile.new("temporary.ttl")
    ttl_file.write(ttl)
    ttl_file.close

    graph_uri = project_name.nil? ? "http://pubannotation.org/docs" : "http://pubannotation.org/projects/#{project_name}"
    destination = "#{Pubann::Application.config.sparql_end_point}/sparql-graph-crud-auth?graph-uri=#{graph_uri}"
    cmd  = %[curl --digest --user #{Pubann::Application.config.sparql_end_point_auth} --verbose --url #{destination} -T #{ttl_file.path}]
    cmd += ' -X POST' unless initp

    message, error, state = Open3.capture3(cmd)

    ttl_file.unlink

    raise RuntimeError, 'Could not store RDFized annotations' unless error.include?('201 Created') || error.include?('200 OK')
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
    doc_annotations_files = Array.new
    # open zip file
    Zip::ZipFile.open(zip_file) do |zipfile|
      zipfile.each do |file|
        file_name = file.name
        if file_name == 'project.json'
          # extract project.json
          file.extract(project_json_file) unless File.exist?(project_json_file)
        elsif file_name == 'docs.json'
          # extract docs.json
          file.extract(docs_json_file) unless File.exist?(docs_json_file)
        else
          # extract sourcedb-sourdeid-serial-section.json
          doc_annotations_file = "#{TempFilePath}#{file.name}"
          unless File.exist?(doc_annotations_file)
            file.extract(doc_annotations_file)
            doc_annotations_files << {name: file.name, path: doc_annotations_file}
          end
        end
      end
    end

    # create project if [project_name]-project.json exist
    if File.exist?(project_json_file)
      params_from_json = Project.params_from_json(project_json_file)
      File.unlink(project_json_file)
      project_params = params_from_json
      project = Project.new(project_params)
      project.user = current_user
      if project.valid?
        project.save
        messages << I18n.t('controllers.shared.successfully_created', model: I18n.t('activerecord.models.project'))
      else
        errors << project.errors.full_messages.join('<br />')
        project = nil
      end
    end

    # create project.docs if [project_name]-docs.json exist
    if project.present?
      if File.exist?(docs_json_file)
        if project.present?
          num_created, num_added, num_failed = project.create_docs_from_json(JSON.parse(File.read(docs_json_file), :symbolize_names => true), current_user)
          messages << I18n.t('controllers.docs.create_project_docs.created_to_document_set', num_created: num_created, project_name: project.name) if num_created > 0
          messages << I18n.t('controllers.docs.create_project_docs.added_to_document_set', num_added: num_added, project_name: project.name) if num_added > 0
          messages << I18n.t('controllers.docs.create_project_docs.failed_to_document_set', num_failed: num_failed, project_name: project.name) if num_failed > 0
        end
        File.unlink(docs_json_file) 
      end

      # save annotations
      if doc_annotations_files
        delay.save_annotations(project, doc_annotations_files)
        messages << I18n.t('controllers.projects.upload_zip.delay_save_annotations')
      end
    end
    return [messages, errors]
  end

  def create_docs_from_json(docs, user)
    num_created, num_added, num_failed = 0, 0, 0
    docs = [docs] if docs.class == Hash
    sourcedbs = docs.group_by{|doc| doc[:sourcedb]}
    if sourcedbs.present?
      sourcedbs.each do |sourcedb, docs_array|
        ids = docs_array.collect{|doc| doc[:sourceid]}.join(",")
        num_created_t, num_added_t, num_failed_t = self.create_docs({ids: ids, sourcedb: sourcedb, docs_array: docs_array, user: user})
        num_created += num_created_t
        num_added += num_added_t
        num_failed += num_failed_t
      end
    end
    return [num_created, num_added, num_failed]   
  end

  def create_docs(options = {})
    num_created, num_added, num_failed = 0, 0, 0
    ids = options[:ids].split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
    ids.each do |sourceid|
      divs = Doc.find_all_by_sourcedb_and_sourceid(options[:sourcedb], sourceid)
      is_current_users_sourcedb = (options[:sourcedb] =~ /.#{Doc::UserSourcedbSeparator}#{options[:user].username}\Z/).present?
      if divs.present?
        if is_current_users_sourcedb
          # when sourcedb is user's sourcedb
          # update or create if not present
          options[:docs_array].each do |doc_array|
            # find doc sourcedb sourdeid and serial
            doc = Doc.find_or_initialize_by_sourcedb_and_sourceid_and_serial(options[:sourcedb], sourceid, doc_array['divid'])
            mappings = {
              'text' => 'body', 
              'section' => 'section', 
              'source_url' => 'source', 
              'divid' => 'serial'
            }

            doc_params = Hash[doc_array.map{|key, value| [mappings[key], value]}].select{|key| key.present?}
            if doc.new_record?
              # when same sourcedb sourceid serial not present
              doc.attributes = doc_params
              if doc.valid?
                # create
                doc.save
                self.docs << doc unless self.docs.include?(doc)
                num_created += 1
              else
                num_failed += 1
              end
            else
              # when same sourcedb sourceid serial present
              # update
              if doc.update_attributes(doc_params)
                self.docs << doc unless self.docs.include?(doc)
                num_added += 1
              else
                num_failed += 1
              end
            end
          end
        else
          # when sourcedb is not user's sourcedb
          unless self.docs.include?(divs.first)
            self.docs << divs
            num_added += divs.size
          end
        end
      else
        if options[:sourcedb].include?(Doc::UserSourcedbSeparator)
          # when sourcedb include : 
          if is_current_users_sourcedb
            # when sourcedb is user's sourcedb
            divs, num_failed_user_sourcedb_docs = create_user_sourcedb_docs(docs_array: options[:docs_array])
            num_failed += num_failed_user_sourcedb_docs
          else
            # when sourcedb is not user's sourcedb
            num_failed += options[:docs_array].size
          end
        else
          # when sourcedb is not user generated
          begin
            # when doc_sequencer_ present
            doc_sequence = Object.const_get("DocSequencer#{options[:sourcedb]}").new(sourceid)
            divs_hash = doc_sequence.divs
            divs = Doc.create_divs(divs_hash, :sourcedb => options[:sourcedb], :sourceid => sourceid, :source_url => doc_sequence.source_url)
          rescue
            # when doc_sequencer_ not present
            divs, num_failed_user_sourcedb_docs = create_user_sourcedb_docs({docs_array: options[:docs_array], sourcedb: "#{options[:sourcedb]}#{Doc::UserSourcedbSeparator}#{options[:user].username}"})
            num_failed += num_failed_user_sourcedb_docs
          end
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

  # returns the divs added to the project
  # returns nil if nothing is added
  def add_docs(sourcedb, sourceids)
    ids_in_pa = Doc.where(sourcedb:sourcedb, sourceid:sourceids).pluck(:sourceid).uniq
    ids_in_pj = ids_in_pa & docs.pluck(:sourceid).uniq

    ids_to_add = ids_in_pa - ids_in_pj
    docs_to_add = Doc.where(sourcedb:sourcedb, sourceid:ids_to_add)

    ids_to_sequence = sourceids - ids_in_pa

    docs_sequenced, messages = ids_to_sequence.present? ? Doc.sequence_docs(sourcedb, ids_to_sequence) : [[], []]

    docs_to_add += docs_sequenced

    docs_to_add.each{|doc| doc.projects << self}
    num_docs_existed = ids_in_pj.length

    # return [num_added, num_sequenced, num_existed, messages]
    [docs_to_add.length, docs_sequenced.length, ids_in_pj.length, messages]
  end

  # returns the divs added to the project
  # returns nil if nothing is added
  def add_doc(sourcedb, sourceid)
    divs = Doc.find_all_by_sourcedb_and_sourceid(sourcedb, sourceid)
    divs, messages = Doc.sequence_docs(sourcedb, [sourceid]) unless divs.present?
    raise RuntimeError, "Failed to get the document" unless divs.present?
    return nil if docs.include?(divs.first)
    divs.each{|div| div.projects << self}
    divs
  end

  def delete_doc(doc)
    raise RuntimeError, "The project does not include the document." unless self.docs.include?(doc)
    delete_doc_annotations(doc)
    doc.projects.delete(self)
    doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{user.username}") && doc.projects_num == 0
  end

  def delete_docs
    delete_annotations if denotations_num > 0

    docs.update_all('projects_num = projects_num - 1')
    docs.update_all(flag:true)

    ## below, former is faster in development, but guess the latter is fater in production (better scale?)
    # docs.delete_all
    ProjectDoc.delete_all(project_id:id)

    Doc.where("sourcedb LIKE '%#{Doc::UserSourcedbSeparator}#{user.username}' AND projects_num = 0").destroy_all

    Doc.__elasticsearch__.import query: -> {where(flag:true)}
    Doc.where(flag:true).update_all(flag:false)
  end

  def create_user_sourcedb_docs(options = {})
    divs = []
    num_failed = 0
    if options[:docs_array].present?
      options[:docs_array].each do |doc_array_params|
        # all of columns insert into database need to be included in this hash.
        doc_array_params[:sourcedb] = options[:sourcedb] if options[:sourcedb].present?
        mappings = {
          :text => :body, 
          :sourcedb => :sourcedb, 
          :sourceid => :sourceid, 
          :section => :section, 
          :source_url => :source, 
          :divid => :serial
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
    end
    return [divs, num_failed]
  end

  def instantiate_hdenotations(hdenotations, docid)
    new_entries = hdenotations.map do |a|
      Denotation.new(
        hid:a[:id],
        begin:a[:span][:begin],
        end:a[:span][:end],
        obj:a[:obj],
        project_id:self.id,
        doc_id:docid
      )
    end
  end

  def instantiate_hrelations(hrelations, docid)
    new_entries = hrelations.map do |a|
      Relation.new(
        hid:a[:id],
        pred:a[:pred],
        subj:Denotation.find_by_doc_id_and_project_id_and_hid(docid, self.id, a[:subj]),
        obj:Denotation.find_by_doc_id_and_project_id_and_hid(docid, self.id, a[:obj]),
        project_id:self.id
      )
    end
  end

  def instantiate_hattributes(hattributes, docid)
    new_entries = hattributes.map do |a|
      Attrivute.new(
        hid:a[:id],
        pred:a[:pred],
        subj:Denotation.find_by_doc_id_and_project_id_and_hid(docid, self.id, a[:subj]),
        obj:a[:obj],
        project_id:self.id
      )
    end
  end

  def instantiate_hmodifications(hmodifications, docid)
    new_entries = hmodifications.map do |a|

      obj = Denotation.find_by_doc_id_and_project_id_and_hid(docid, self.id, a[:obj])
      if obj.nil?
        doc = Doc.find(docid)
        doc.subcatrels.find_by_project_id_and_hid(self.id, a[:obj])
      end
      raise ArgumentError, "Invalid object of modification: #{a[:id]}" if obj.nil?

      Modification.new(
        hid:a[:id],
        pred:a[:pred],
        obj:obj,
        project_id:self.id
      )
    end
  end

  def instantiate_and_save_annotations(annotations, doc)
    ActiveRecord::Base.transaction do
      if annotations[:denotations].present?
        instances = instantiate_hdenotations(annotations[:denotations], doc.id)
        if instances.present?
          r = Denotation.import instances, validate: false
          raise "denotations import error" unless r.failed_instances.empty?
          ProjectDoc.find_by_project_id_and_doc_id(id, doc.id).increment!(:denotations_num, instances.length)
          doc.increment!(:denotations_num, instances.length)
          self.increment!(:denotations_num, instances.length)
        end
      end

      if annotations[:relations].present?
        instances = instantiate_hrelations(annotations[:relations], doc.id)
        if instances.present?
          r = Relation.import instances, validate: false
          raise "relations import error" unless r.failed_instances.empty?
          ProjectDoc.find_by_project_id_and_doc_id(id, doc.id).increment!(:relations_num, instances.length)
          doc.increment!(:relations_num, instances.length)
          self.increment!(:relations_num, instances.length)
        end
      end

      if annotations[:attributes].present?
        instances = instantiate_hattributes(annotations[:attributes], doc.id)
        if instances.present?
          r = Attrivute.import instances, validate: false
          raise "attributes import error" unless r.failed_instances.empty?
        end
      end

      if annotations[:modifications].present?
        instances = instantiate_hmodifications(annotations[:modifications], doc.id)
        if instances.present?
          r = Modification.import instances, validate: false
          raise "modifications import error" unless r.failed_instances.empty?
          ProjectDoc.find_by_project_id_and_doc_id(id, doc.id).increment!(:modifications_num, instances.length)
          doc.increment!(:modifications_num, instances.length)
          self.increment!(:modifications_num, instances.length)
        end
      end
    end
  end

  def instantiate_and_save_annotations_collection(annotations_collection)
    ActiveRecord::Base.transaction do

      # collect statistics
      d_stat, r_stat, m_stat = Hash.new(0), Hash.new(0), Hash.new(0)

      # cache document id
      annotations_collection.each do |ann|
        ann[:docid] = ann[:divid].nil? ?
          Doc.find_by_sourcedb_and_sourceid(ann[:sourcedb], ann[:sourceid]).id :
          Doc.find_by_sourcedb_and_sourceid_and_serial(ann[:sourcedb], ann[:sourceid], ann[:divid]).id
      end

      # instantiate and save denotations
      instances = []
      annotations_collection.each do |ann|
        next unless ann[:denotations].present?
        docid = ann[:docid]
        instances += instantiate_hdenotations(ann[:denotations], docid)
        d_stat[docid] += ann[:denotations].length
      end

      if instances.present?
        r = Denotation.import instances, validate: false
        raise "denotations import error" unless r.failed_instances.empty?
      end

      d_stat_all = instances.length

      # instantiate and save relations
      instances.clear
      annotations_collection.each do |ann|
        next unless ann[:relations].present?
        docid = ann[:docid]
        instances += instantiate_hrelations(ann[:relations], docid)
        r_stat[docid] += ann[:relations].length
      end

      if instances.present?
        r = Relation.import instances, validate: false
        raise "relation import error" unless r.failed_instances.empty?
      end

      r_stat_all = instances.length

      # instantiate and save attributes
      instances.clear
      annotations_collection.each do |ann|
        next unless ann[:attributes].present?
        docid = ann[:docid]
        instances += instantiate_hattributes(ann[:attributes], docid)
      end

      if instances.present?
        r = Attrivute.import instances, validate: false
        raise "attribute import error" unless r.failed_instances.empty?
      end

      # instantiate and save modifications
      instances.clear
      annotations_collection.each do |ann|
        next unless ann[:modifications].present?
        docid = ann[:docid]
        instances += instantiate_hmodifications(ann[:modifications], docid)
        m_stat[docid] += ann[:modifications].length
      end

      if instances.present?
        r = Modification.import instances, validate: false
        raise "modifications import error" unless r.failed_instances.empty?
      end

      m_stat_all = instances.length

      d_stat.each do |did, d_num|
        r_num = r_stat[did] ||= 0
        a_num = a_stat[did] ||= 0
        m_num = m_stat[did] ||= 0
        connection.execute("update project_docs set denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where project_id=#{id} and doc_id=#{did}")
        connection.execute("update docs set denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where id=#{did}")
      end

      self.update_attributes!(
        denotations_num: denotations_num + d_stat_all,
        relations_num: relations_num + r_stat_all,
        modifications_num: modifications_num + m_stat_all
      )
    end
  end

  # annotations need to be normal
  def save_annotations(annotations, doc, options = nil)
    raise ArgumentError, "nil document" unless doc.present?
    raise ArgumentError, "the project does not have the document" unless doc.projects.include?(self)
    options ||= {}

    return {result: 'upload is skipped due to existing annotations'} if options[:mode] == 'skip' && doc.denotations_count > 0

    annotations = Annotation.prepare_annotations(annotations, doc, options)

    delete_doc_annotations(doc, options[:span]) if options[:mode] == 'replace'
    instantiate_and_save_annotations(annotations, doc)

    annotations
  end

  def save_annotations_divs(annotations, divs, options = {})
    raise ArgumentError, "nil divs" unless divs.present?
    raise ArgumentError, "the project does not have the document" unless divs.first.projects.include?(self)
    options ||= {}

    if options[:mode] == 'skip'
      num = Denotations.where(project_id:self.id, sourcedb:divs.first.sourcedb, sourceid:divs.first.sourceid).count
      return {result: 'upload is skipped due to existing annotations'} if num > 0
    end

    annotations_collection = Annotation.prepare_annotations_divs(annotations, divs)

    divs.each{|div| delete_doc_annotations(div)} if options[:mode] == 'replace'
    instantiate_and_save_annotations_collection(annotations_collection)

    annotations_collection
  end

  # It assumes that
  # - annotations are already normal, and
  # - documents exist in the database
  def store_annotations_collection(annotations_collection, options)
    messages = []
    num_skipped = 0

    aligned_collection = annotations_collection.inject([]) do |col, annotations|

      doc, divs = if annotations[:divid].present?
        d = Doc.find_by_sourcedb_and_sourceid_and_serial(annotations[:sourcedb], annotations[:sourceid], annotations[:divid])
        [d, nil]
      else
        s = Doc.find_all_by_sourcedb_and_sourceid(annotations[:sourcedb], annotations[:sourceid])
        if s.length == 1
          [s[0], nil]
        else
          [nil, s]
        end
      end

      if doc.present?

        if options[:mode] == 'skip'
          num = ProjectDoc.where(project_id:id, doc_id:doc.id).limit(1).pluck(:denotations_num).first
          if num > 0
            num_skipped += 1
            next
          end
        end

        begin
          col << Annotation.prepare_annotations(annotations, doc)
          delete_doc_annotations(doc) if options[:mode] == 'replace'
        rescue => e
          messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], body: e.message}
        end

      elsif divs.present?

        if options[:mode] == 'skip'
          num = Denotation.joins(:docs).where(project_id:id, 'docs.sourcedb' => annotations[:sourcedb], 'docs.sourceid' => annotations[:sourceid]).limit(1).count
          if num > 0
            num_skipped += 1
            next
          end
        end

        begin
          col += Annotation.prepare_annotations_divs(annotations, divs)
          divs.each{|d| delete_doc_annotations(d)} if options[:mode] == 'replace'
        rescue => e
          messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message}
        end

      else
        messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: 'document does not exist.'}
      end

      col
    end

    messages << {body: "Uploading for #{num_skipped} documents were skipped due to existing annotations."} if num_skipped > 0

    instantiate_and_save_annotations_collection(aligned_collection) if aligned_collection.present?

    messages
  end

  # To obtain annotations from an annotator and to save them in the project
  def obtain_annotations(docids, annotator, options = nil)
    options ||= {}
    messages = []

    docs = docids.map{|docid| Doc.find(docid)}
    if options[:encoding] == 'ascii'
      docs.each do |doc|
        begin
          doc.set_ascii_body
        rescue => e
          # This message may not be captured due to exceptions
          messages << {sourcedb:doc.sourcedb, sourceid:doc.sourceid, divid:doc.serial, body:"The document is processed without changing to ASCII: #{e.message}"}
        end
      end
    end

    method, url, params, payload = prepare_request(docs, annotator, options)

    result = make_request(method, url, params, payload)
    annotations_col = (result.class == Array) ? result : [result]

    # To recover the identity information, in case of syncronous annotation
    annotations_col.each_with_index do |annotations, i|
      raise RuntimeError, "Invalid annotation JSON object." unless annotations.respond_to?(:has_key?)
      annotations[:text] = docs[i].body unless annotations[:text].present?
      annotations[:sourcedb] = docs[i].sourcedb unless annotations[:sourcedb].present?
      annotations[:sourceid] = docs[i].sourceid unless annotations[:sourceid].present?
      annotations[:divid] = docs[i].serial unless annotations[:divid].present?
      Annotation.normalize!(annotations, options[:prefix])
    end

    store_annotations_collection(annotations_col, options)
    [annotations_col, messages]
  end

  def prepare_request(docs, annotator, options)
    method = (annotator[:method] == 0) ? :get : :post

    params = if method == :get
      # The URL of an annotator should include the placeholder of either _text_ or  _sourceid_.
      # Otherwise, the default params will be automatically added.
      if annotator[:url].include?('_text_') || annotator[:url].include?('_sourceid_')
        # In this case, the number of document has to be 1.
        raise RuntimeError, "Only one document can be passed to the annotation server through a GET request." unless docs.length == 1
        nil
      else
        {"text"=>"_text_"}
      end
    end

    # In case of GET method, only one document can be passed to the annotation server.
    doc = docs.first

    url = annotator[:url]
      .gsub('_text_', URI.escape(doc.body))
      .gsub('_sourcedb_', URI.escape(doc.sourcedb))
      .gsub('_sourceid_', URI.escape(doc.sourceid))

    if params.present?
      params.each do |k, v|
        params[k] = v.gsub('_text_', doc.body).gsub('_sourcedb_', doc.sourcedb).gsub('_sourceid_', doc.sourceid)
      end
    end

    payload = if (method == :post)
      # The default payload
      annotator[:payload]['_body_'] = '_doc_' unless annotator[:payload].present?

      if annotator[:payload]['_body_'] == '_text_'
        docs.map{|doc| doc.body}
      elsif annotator[:payload]['_body_'] == '_doc_'
        docs.map{|doc| doc.hannotations(self).select{|k, v| [:text, :sourcedb, :sourceid, :divid].include? k}}
      elsif annotator[:payload]['_body_'] == '_annotation_'
        docs.map{|doc| doc.hannotations(self)}
      end
    end

    payload = payload.first if payload.present? && (!annotator[:batch_num].present? || annotator[:batch_num] == 0)

    [method, url, params, payload]
  end

  def make_request(method, url, params = nil, payload = nil)
    payload, payload_type = if payload.class == String
      [payload, 'text/plain; charset=utf8']
    else
      [payload.to_json, 'application/json; charset=utf8']
    end

    response = if method == :post && !payload.nil?
      RestClient::Request.execute(method: method, url: url, payload: payload, max_redirects: 0, headers:{content_type: payload_type, accept: :json})
    else
      RestClient::Request.execute(method: method, url: url, max_redirects: 0, headers:{params: params, accept: :json})
    end

    result = begin
      JSON.parse response, :symbolize_names => true
    rescue => e
      raise RuntimeError, "Received a non-JSON object: [#{response}]"
    end
  end

  def get_textae_config
    textae_config.present? ? make_request(:get, textae_config) : {}
  end

  def user_presence
    if user.blank?
      errors.add(:user_id, 'is blank') 
    end
  end

  def namespaces_base
    namespaces.find{|namespace| namespace['prefix'] == '_base'} if namespaces.present?
  end

  def base_uri
    namespaces_base['uri'] if namespaces_base.present?
  end

  def namespaces_prefixes
    namespaces.select{|namespace| namespace['prefix'] != '_base'} if namespaces.present?
  end

  # delete empty value hashes
  def cleanup_namespaces
    namespaces.reject!{|namespace| namespace['prefix'].blank? || namespace['uri'].blank?} if namespaces.present?
  end

  def delete_annotations
    Modification.delete_all(project_id:self.id)
    Relation.delete_all(project_id:self.id)
    Denotation.delete_all(project_id:self.id)

    connection.execute("update project_docs set denotations_num = 0, relations_num=0, modifications_num=0 where project_id=#{id}")

    if docs.count < 1000000
      connection.execute("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})")
      connection.execute("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if relations_num > 0
      connection.execute("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id)) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if modifications_num > 0
    else
      connection.execute("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id)")
      connection.execute("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id)") if relations_num > 0
      connection.execute("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id))") if modifications_num > 0
    end

    update_attributes!(denotations_num: 0, relations_num: 0, modifications_num: 0)

    update_updated_at
  end

  def delete_doc_annotations(doc, span = nil)
    if span.present?
      denotations = doc.get_denotations(self, span)
      denotations.each{|d| d.destroy}
    else
      modifications = doc.catmods.where(project_id: self.id) + doc.subcatrelmods.where(project_id: self.id)
      relations = doc.subcatrels.where(project_id: self.id)
      denotations = doc.denotations.where(project_id: self.id)

      doc.decrement!(:modifications_num, modifications.length)
      doc.decrement!(:denotations_num, denotations.length)
      doc.decrement!(:relations_num, relations.length)

      decrement!(:modifications_num, modifications.length)
      decrement!(:relations_num, relations.length)
      decrement!(:denotations_num, denotations.length)

      Modification.delete(modifications)
      Relation.delete(relations)
      Denotation.delete(denotations)

      ProjectDoc.find_by_project_id_and_doc_id(id, doc.id).update_attributes!(denotations_num: 0, relations_num: 0, modifications_num: 0)
      update_updated_at
    end
  end

  def update_updated_at
    self.update_attribute(:updated_at, DateTime.now)
  end

  def clean
    connection.execute "update project_docs set (denotations_num) = (select count(*) from denotations where denotations.doc_id=project_docs.doc_id and denotations.project_id=#{id})"
    # connection.execute "update project_docs set (relations_num) = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = project_docs.doc_id and relations.project_id=#{id})"
    # connection.execute "update project_docs set (modifications_num) = row((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = project_docs.id and modifications.project_id=project_docs.project_id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=project_docs.doc_id and modifications.project_id=#{id}))"

    denotations_num = denotations.count
    relations_num = relations.count
    modifications_num = modifications.count

    pmdocs_count = docs.where(sourcedb: "PubMed").count
    pmcdocs_count = docs.where(sourcedb: "PMC").count
    update_attributes(
      pmdocs_count: pmdocs_count,
      pmcdocs_count: pmcdocs_count,
      denotations_num: denotations_num,
      relations_num: relations_num,
      modifications_num: relations_num,
      annotations_count: denotations_num + relations_num + modifications_num
    )
  end
end
