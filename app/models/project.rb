class Project < ActiveRecord::Base
  include ApplicationHelper
  include AnnotationsHelper
  DOWNLOADS_PATH = "/downloads/"
  COMPARISONS_PATH = "public/comparisons/"

  before_validation :cleanup_namespaces
  after_validation :user_presence
  serialize :namespaces
  belongs_to :user
  has_and_belongs_to_many :docs, 
    :after_add => [:increment_docs_counter, :update_annotations_updated_at, :increment_docs_projects_num, :update_delta_index], 
    :after_remove => [:decrement_docs_counter, :update_annotations_updated_at, :decrement_docs_projects_num, :update_delta_index]
  has_and_belongs_to_many :pmdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PubMed'}
  has_and_belongs_to_many :pmcdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PMC', :serial => 0}
  has_many :divs, through: :docs

  attr_accessible :name, :description, :author, :anonymize, :license, :status, :accessibility, :reference,
                  :sample, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter,
                  :annotations_zip_downloadable, :namespaces, :process,
                  :pmdocs_count, :pmcdocs_count, :denotations_count, :relations_count, :annotations_count
  has_many :denotations, :dependent => :destroy, after_add: :update_updated_at
  has_many :relations, :dependent => :destroy, after_add: :update_updated_at
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
        includes(:associate_maintainers).where('projects.accessibility = ? OR projects.accessibility = ? OR projects.user_id =? OR associate_maintainers.user_id =?', 1, 3, current_user.id, current_user.id)
      end
    else
      where(accessibility: [1, 3])
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
    order('annotations_count DESC').order('projects.updated_at DESC').order('status ASC').limit(10)

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

  # default sort order priority : left > right
  DefaultSortKey = "status ASC"

  LicenseDefault = 'Creative Commons Attribution 3.0 Unported License'
  EditorDefault = 'http://textae.pubannotation.org/editor.html?mode=edit'
  
  def public?
    accessibility == 1
  end

  def accessible?(current_user)
    self.accessibility == 1 || self.user == current_user || current_user.root?
  end

  def editable?(current_user)
    current_user.present? && (current_user.root? || current_user == user || self.associate_maintainer_users.include?(current_user))
  end

  def destroyable?(current_user)
    current_user.root? || current_user == user  
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
    end
  end

  def update_delta_index(doc)
    doc.save
  end

  def increment_docs_projects_num(doc)
    Doc.increment_counter(:projects_num, doc.id)
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
    end          
  end          

  def decrement_docs_projects_num(doc)
    Doc.decrement_counter(:projects_num, doc.id)
    doc.reload
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
  
  def get_denotations_count(doc = nil, span = nil)
    if doc.nil?
      self.denotations_count
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

  def has_doc?(sourcedb, sourceid)
    doc = self.docs.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
    doc.present? ? doc.divs.present? : false
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
        raise IOError, "Bad response from the converter"
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

  def post_rdf(ttl, project_name = nil, initp = false)
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

    raise IOError, 'Could not store RDFized annotations' unless error.include?('201 Created') || error.include?('200 OK')
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
          num_created, num_added, num_failed = project.add_docs_from_json(JSON.parse(File.read(docs_json_file), :symbolize_names => true), current_user)
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

  def add_docs_from_json(docs, user)
    num_created, num_added, num_failed = 0, 0, 0
    docs = [docs] if docs.class == Hash
    sourcedbs = docs.group_by{|doc| doc[:sourcedb]}
    if sourcedbs.present?
      sourcedbs.each do |sourcedb, docs_array|
        ids = docs_array.collect{|doc| doc[:sourceid]}.join(",")
        num_created_t, num_added_t, num_failed_t = self.add_docs({ids: ids, sourcedb: sourcedb, docs_array: docs_array, user: user})
        num_created += num_created_t
        num_added += num_added_t
        num_failed += num_failed_t
      end
    end
    return [num_created, num_added, num_failed]   
  end

  def add_docs(options = {})
    num_created, num_added, num_failed = 0, 0, 0
    ids = options[:ids].split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
    ids.each do |sourceid|
      doc = Doc.find_by_sourcedb_and_sourceid(options[:sourcedb], sourceid)
      divs = doc.divs if doc
      is_current_users_sourcedb = (options[:sourcedb] =~ /.#{Doc::UserSourcedbSeparator}#{options[:user].username}\Z/).present?
      if divs.present?
        if is_current_users_sourcedb
          # TODO create method to create doc and divs from docs_array
          # when sourcedb is user's sourcedb
          # update or create if not present
          body_for_base_doc = options[:docs_array].collect{|doc_array| doc_array['text'].chomp + '\n' if doc_array['text']}.join('')

          # doc
          # doc = Doc.find_or_initialize_by_sourcedb_and_sourceid_and_serial(options[:sourcedb], sourceid, 0)
          mappings = {
            'text' => 'body', 
            'section' => 'section', 
            'source_url' => 'source', 
            'divid' => 'serial'
          }
          doc_params = Hash[options[:docs_array].map{|key, value| [mappings[key], value]}].select{|key| key.present?}
          doc_params['body'] = body_for_base_doc
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

          options[:docs_array].each do |doc_array|
            body = ''
            # find doc sourcedb sourdeid and serial
            div_id = doc_array['divid'] 
            div = doc.divs.find_by_serial(div_id)

            # set begin end by text(doc.body) 
            if doc_array["text"]
              div_body = doc_array["text"].chomp + '\n' 
              if div_id == 0
                begin_pos = 0
                end_pos = div_body.length
              else
                begin_pos = body.length
                end_pos = body.length + div_body.length
              end
              body += div_body
            end

            div_attributes = {begin: begin_pos, end: end_pos, section: doc_array['section'], serial: div_id}
            if div.blank?
              # when same sourcedb sourceid serial not present
              div = Div.new div_attributes
              if div.valid?
                # create
                div.save
                num_created += 1
              else
                num_failed += 1
              end
            else
              # when same sourcedb sourceid serial present
              # update
              if div.update_attributes(div_attributes)
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
  def add_doc_unless_exist(sourcedb, sourceid)
    doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
    divs = doc.divs if doc
    divs = Doc.import_from_sequence(sourcedb, sourceid) unless divs.present?
    raise IOError, "Failed to get the document" unless divs.present?
    return nil if self.docs.include?(doc)
    divs
  end

  def add_doc(sourcedb, sourceid, strictp = false)
    doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
    divs = doc.divs if doc

    if divs.present?
      if self.docs.include?(doc)
        raise ArgumentError, "The document already exists" if strictp
      else
        self.docs << doc
      end
    else
      divs = Doc.import_from_sequence(sourcedb, sourceid)
      raise IOError, "Failed to get the document" unless divs.present?
      self.docs << divs.first.doc
    end
    divs
  end

  def create_user_sourcedb_docs(options = {})
    divs = []
    num_failed = 0
    if options[:docs_array].present?
      options[:docs_array].each do |doc_array_params|
        # all of columns insert into database need to be included in this hash.
        # TODO create method to create doc and divs from docs_array
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

  def save_hdenotations(hdenotations, doc)
    hdenotations.each do |a|
      ca           = Denotation.new
      ca.hid       = a[:id]
      ca.begin     = a[:span][:begin]
      ca.end       = a[:span][:end]
      ca.obj       = a[:obj]
      ca.project_id = self.id
      ca.doc_id    = doc.id
      raise ArgumentError, "Invalid representation of denotation: #{ca.hid}" unless ca.save
    end
  end

  def save_hrelations(hrelations, doc)
    hrelations.each do |a|
      ra           = Relation.new
      ra.hid       = a[:id]
      ra.pred      = a[:pred]
      ra.subj      = Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, self.id, a[:subj])
      ra.obj       = Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, self.id, a[:obj])
      ra.project_id = self.id
      raise ArgumentError, "Invalid representation of relation: #{ra.hid}" unless ra.save
    end
  end

  def save_hmodifications(hmodifications, doc)
    hmodifications.each do |a|
      ma        = Modification.new
      ma.hid    = a[:id]
      ma.pred   = a[:pred]
      ma.obj    = case a[:obj]
        when /^R/
          doc.subcatrels.find_by_project_id_and_hid(self.id, a[:obj])
        else
          Denotation.find_by_doc_id_and_project_id_and_hid(doc.id, self.id, a[:obj])
      end
      ma.project_id = self.id
      raise ArgumentError, "Invalid representatin of modification: #{ma.hid}" unless ma.save
    end
  end

  def save_annotations(annotations, doc, options = nil)
    raise ArgumentError, "nil document" unless doc.present?
    raise ArgumentError, "the project does not have the document" unless doc.projects.include?(self)
    options ||= {}

    if options[:mode] == 'skip'
      num = doc.denotations.where("denotations.project_id = ?", id).count
      return {result: 'upload is skipped due to existing annotations'} if num > 0
    end

    self.delete_annotations(doc) if options[:mode] == 'replace'

    original_text = annotations[:text]
    annotations[:text] = doc.original_body.nil? ? doc.body : doc.original_body

    if annotations[:denotations].present?
      num = annotations[:denotations].length

      annotations[:denotations] = align_denotations(annotations[:denotations], original_text, annotations[:text])

      raise "Alignment failed. Text may be too much different." if annotations[:denotations].length < num
      annotations[:denotations].each{|d| raise "Alignment failed. Text may be too much different." if d[:span][:begin].nil? || d[:span][:end].nil?}

      self.save_hdenotations(annotations[:denotations], doc)
      self.save_hrelations(annotations[:relations], doc) if annotations[:relations].present?
      self.save_hmodifications(annotations[:modifications], doc) if annotations[:modifications].present?
    end

    result = annotations.select{|k,v| v.present?}
  end

  def store_annotations(annotations, divs, options = {})
    options ||= {}
    successful = true
    fit_index = nil

    if divs.length == 1
      self.save_annotations(annotations, divs[0], options)
    else
      div_index = divs.collect{|d| [d.serial, d]}.to_h
      divs_hash = divs.collect{|d| d.to_hash}
      fit_index = TextAlignment.find_divisions(annotations[:text], divs_hash)

      fit_index.each do |i|
        if i[0] >= 0
          ann = {divid:i[0]}
          idx = {}
          ann[:text] = annotations[:text][i[1][0] ... i[1][1]]
          if annotations[:denotations].present?
            ann[:denotations] = annotations[:denotations]
                                 .select{|a| a[:span][:begin] >= i[1][0] && a[:span][:end] <= i[1][1]}
                                .collect{|a| n = a.dup; n[:span] = a[:span].dup; n}
                                   .each{|a| a[:span][:begin] -= i[1][0]; a[:span][:end] -= i[1][0]}
            ann[:denotations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:relations].present?
            ann[:relations] = annotations[:relations].select{|a| idx[a[:subj]] && idx[a[:obj]]}
            ann[:relations].each{|a| idx[a[:id]] = true}
          end
          if annotations[:modifications].present?
            ann[:modifications] = annotations[:modifications].select{|a| idx[a[:obj]]}
            ann[:modifications].each{|a| idx[a[:id]] = true}
          end
          self.save_annotations(ann, div_index[i[0]], options)
        end
      end
      {div_index: fit_index}
    end
  end

  def store_annotation_transaction(annotation_collection, options)
    messages = []
    ActiveRecord::Base.transaction do
      annotation_collection.each do |annotations|
        if annotations[:divid].present?
          doc = Doc.find_by_sourcedb_and_sourceid_and_serial(annotations[:sourcedb], annotations[:sourceid], annotations[:divid])
        else
          divs = Doc.find_all_by_sourcedb_and_sourceid(annotations[:sourcedb], annotations[:sourceid])
          doc = divs[0] if divs.length == 1
        end

        if doc.present?
          begin
            self.save_annotations(annotations, doc, options)
          rescue => e
            messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], body: e.message}
          end
        elsif divs.present?
          begin
            self.store_annotations(annotations, divs, options)
          rescue => e
            messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message}
          end
        else
          messages << {sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: 'document does not exist.'}
        end
      end
    end
    messages
  end

  def obtain_annotations(doc, annotator, options = nil)
    options ||= {}

    if options[:mode] == 'skip'
      num = doc.denotations.where("denotations.project_id = ?", id).count
      return {result: 'obtaining annotation is skipped due to existing annotations'} if num > 0
    end

    annotations = inquire_annotations(doc, annotator, options)
    normalize_annotations!(annotations)

    prefix = annotator['abbrev']
    if prefix.present?
      annotations[:denotations].each {|a| a[:id] = prefix + '_' + a[:id]} if annotations[:denotations].present?
      annotations[:relations].each {|a| a[:id] = prefix + '_' + a[:id]; a[:subj] = prefix + '_' + a[:subj]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:relations].present?
      annotations[:modifications].each {|a| a[:id] = prefix + '_' + a[:id]; a[:obj] = prefix + '_' + a[:obj]} if annotations[:modifications].present?
    end

    result = self.save_annotations(annotations, doc, options)
  end

  def inquire_annotations(doc, annotator, options = nil)
    doc.set_ascii_body if options[:encoding] == 'ascii'

    url = annotator['url']
      .gsub('_text_', doc.body)
      .gsub('_sourcedb_', doc.sourcedb)
      .gsub('_sourceid_', doc.sourceid)

    params = {}
    annotator['params'].each do |k, v|
      params[k] = v
        .gsub('_text_', doc.body)
        .gsub('_sourcedb_', doc.sourcedb)
        .gsub('_sourceid_', doc.sourceid)
    end

    response = begin
      if annotator['method'] == 0 # 'get'
        RestClient.get url, {:params => params, :accept => :json}
      else
        RestClient::Request.execute(method: :post, url: url, timeout: 120, payload: params)
        # RestClient.post url, params.merge({:accept => :json})
      end
    rescue => e
      raise IOError, "Invalid connection"
    end
    raise IOError, "Bad gateway" unless response.code == 200

    begin
      result = JSON.parse response, :symbolize_names => true
    rescue => e
      raise IOError, "Received a non-JSON object: [#{response}]"
    end

    ann = {}
    ann[:text] = if result.respond_to?(:has_key?) && result.has_key?(:text)
      result[:text]
    else
      doc.body
    end

    if result.respond_to?(:has_key?) && result.has_key?(:denotations)
      ann[:denotations] = result[:denotations]
      ann[:relations] = result[:relations] if defined? result[:relations]
      ann[:modifications] = result[:modifications] if defined? result[:modifications]
    elsif result.respond_to?(:first) && result.first.respond_to?(:has_key?) && result.first.has_key?(:obj)
      ann[:denotations] = result
    end

    ann
  end

  def comparison_path
    "#{Project::COMPARISONS_PATH}" + "comparison_#{self.name}" + '.json'
  end

  def create_comparison(project_ref)
    docs = self.docs & project_ref.docs

    comparison_simple = compare_annotations(project_ref, docs)
    comparison_composite = compare_annotations(project_ref, docs, true)

    comparison = {reference: project_ref.name, individual: comparison_simple, compound: comparison_composite}

    File.write(comparison_path, comparison.to_json)
  end

  def compare_annotations(project_ref, docs, compositep = false)
    cmp_denotations = {counts:Hash.new(0), counts_ref:Hash.new(0), counts_common:Hash.new(0)}
    cmp_relations = {counts:Hash.new(0), counts_ref:Hash.new(0), counts_common:Hash.new(0)}
    cmp_modifications = {counts:Hash.new(0), counts_ref:Hash.new(0), counts_common:Hash.new(0)}

    docs.each do |doc|
      anns     = get_normalized_annotations(self, doc, compositep)
      anns_ref = get_normalized_annotations(project_ref, doc, compositep)

      count_denotations(anns[:denotations], cmp_denotations[:counts])
      count_denotations(anns_ref[:denotations], cmp_denotations[:counts_ref])
      count_denotations(anns[:denotations] & anns_ref[:denotations], cmp_denotations[:counts_common])

      count_relations(anns[:relations], cmp_relations[:counts])
      count_relations(anns_ref[:relations], cmp_relations[:counts_ref])
      count_relations(anns[:relations] & anns_ref[:relations], cmp_relations[:counts_common])

      count_modifications(anns[:modifications], cmp_modifications[:counts])
      count_modifications(anns_ref[:modifications], cmp_modifications[:counts_ref])
      count_modifications(anns[:modifications] & anns_ref[:modifications], cmp_modifications[:counts_common])
    end

    compute_performance(cmp_denotations)
    compute_performance(cmp_relations)
    compute_performance(cmp_modifications)

    {denotations:cmp_denotations, relations:cmp_relations, modifications:cmp_modifications}
  end

  def count_denotations(denotations, counts)
    denotations.each{|d| counts[d[:obj]] += 1; counts['_ALL_'] += 1}
    counts
  end

  def count_relations(relations, counts)
    relations.each{|r| counts[r[:pred]] += 1; counts['_ALL_'] += 1}
    counts
  end

  def count_modifications(modifications, counts)
    modifications.each{|m| counts[m[:pred]] += 1; counts['_ALL_'] += 1}
    counts
  end

  def compute_performance(comparison)
    counts = comparison[:counts]
    counts_ref = comparison[:counts_ref]
    counts_common = comparison[:counts_common]
    recall = Hash.new(0)
    precision = Hash.new(0)
    fscore = Hash.new(0)

    counts_ref.each{|t, c| a = counts[t]; precision[t] = (a == 0 ? 0 : counts_common[t].to_f / a)}
    counts_ref.each{|t, c| recall[t] = counts_common[t].to_f / c}
    counts_ref.each{|t, c| fscore[t] = (precision[t] + recall[t] == 0) ? 0 : 2.to_f * precision[t] * recall[t] / (precision[t] + recall[t])}

    comparison[:recall] = recall
    comparison[:precision] = precision
    comparison[:fscore] = fscore
  end

  def get_normalized_annotations(project, doc, compositep = false)
    anns = doc.hannotations(project)
    if anns.has_key?(:denotations)
      denotations_idx = anns[:denotations].inject({}){|idx, d| idx[d[:id]] = {span:d[:span], obj:d[:obj]}; idx}

      if compositep
        dependency_idx = {}
        if anns.has_key?(:relations)
          anns[:relations].each do |r|
            dependency_idx[r[:obj]] = [] if dependency_idx[r[:obj]].nil?
            dependency_idx[r[:obj]] << r[:subj]
          end
        end

        denotations_idx.each{|id, d| composite_denotation(id, denotations_idx, dependency_idx)}
      end

      denotations   = denotations_idx.values.uniq
      relations     = anns[:relations].collect{|r| {subj:denotations_idx[r[:subj]], obj:denotations_idx[r[:obj]], pred:r[:pred]}}.uniq if anns.has_key?(:relations)
      modifications = anns[:modifications].collect{|r| {obj:denotations_idx[r[:obj]], pred:r[:pred]}}.uniq if anns.has_key?(:modifications)
    end

    denotations ||= []
    relations ||= []
    modifications ||= []
    {denotations: denotations, relations: relations, modifications: modifications}
  end

  def composite_denotation(did, denotations_idx, dependency_idx, stack = [])
    if denotations_idx[did].has_key?(:dep) || dependency_idx[did].nil?
    else
      deps = dependency_idx[did] - stack
      denotations_idx[did][:dep] = deps.collect{|c| composite_denotation(c, denotations_idx, dependency_idx, stack << c)}
    end
    denotations_idx[did]
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

  def delete_doc(doc, current_user)
    raise RuntimeError, "The project does not include the document." unless self.docs.include?(doc)
    self.delete_annotations(doc)
    self.docs.delete(doc)
    doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{current_user.username}") && doc.projects_num == 0
  end

  def delete_annotations(doc)
    self.denotations.where(doc_id: doc.id).destroy_all
  end

  def update_updated_at(model)
    self.update_attribute(:updated_at, DateTime.now)
  end

  def clean
    denotations_count = annotations_collection.inject(0){|sum, ann| sum += (ann[:denotations].present? ? ann[:denotations].length : 0)}
    relations_count = annotations_collection.inject(0){|sum, ann| sum += (ann[:relations].present? ? ann[:relations].length : 0)}
    pmdocs_count = docs.where(sourcedb: "PubMed").count
    pmcdocs_count = docs.where(sourcedb: "PMC").count
    update_attributes(
      :pmdocs_count => pmdocs_count,
      :pmcdocs_count => pmcdocs_count,
      :denotations_count => denotations_count,
      :relations_count => relations_count,
      :annotations_count => denotations_count + relations_count
    )
  end
end
