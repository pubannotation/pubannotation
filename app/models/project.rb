class Project < ActiveRecord::Base
  DOWNLOADS_PATH = "/downloads/"

  before_validation :cleanup_namespaces
  after_validation :user_presence
  serialize :namespaces
  belongs_to :user
  belongs_to :annotator, optional: true
  has_many :collection_projects, dependent: :destroy
  has_many :collections, through: :collection_projects
  has_many :project_docs, dependent: :destroy
  has_many :docs, through: :project_docs
  has_many :queries, as: :organization, :dependent => :destroy

  has_many :evaluations, foreign_key: 'study_project_id'
  has_many :evaluatees, class_name: 'Evaluation', foreign_key: 'reference_project_id'

  has_many :denotations, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :blocks, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :relations, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :attrivutes, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintainer_users, :through => :associate_maintainers, :source => :user, :class_name => 'User'
  has_many :jobs, as: :organization, :dependent => :destroy
  validates :name, :presence => true, :length => { :minimum => 5, :maximum => 40 }, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9\-_]+\z/i

  def as_json(options = {})
    options ||= {}
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

  default_scope { where(:type => nil) }

  scope :for_index, -> { where('accessibility = 1 AND status < 3') }
  scope :for_home, -> { where('accessibility = 1 AND status < 4') }

  scope :public_or_blind, -> { where(accessibility: [1, 3]) }

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

  scope :annotations_accessible, -> (current_user) {
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
        includes(:associate_maintainers).where('projects.user_id =? OR associate_maintainers.user_id =?', current_user.id, current_user.id).references(:associate_maintainers)
      end
    else
      where(accessibility: 10)
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
  scope :top_annotations_count, -> {
    order('denotations_num DESC').order('projects.updated_at DESC').order('status ASC').limit(10)
  }

  scope :top_recent, -> {
    order('projects.updated_at DESC').order('annotations_count DESC').order('status ASC').limit(10)
  }

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

  def small?
    docs.count < 200
  end

  def build_associate_maintainers(usernames)
    if usernames.present?
      users = User.where('username IN (?)', usernames)
      users = users.uniq if users.present?
      users.each do |user|
        self.associate_maintainers.build({ :user_id => user.id })
      end
    end
  end

  def get_denotations_count(doc = nil, span = nil)
    return self.denotations_num if doc.nil?
    doc.get_denotations_count(id, span)
  end

  def get_blocks_count(doc = nil, span = nil)
    return self.blocks_num if doc.nil?
    doc.get_blocks_count(id, span)
  end

  def get_relations_count(doc = nil, span = nil)
    return self.relations_num if doc.nil?
    return ActiveRecord::Base.connection.select_value "SELECT relations_num FROM project_docs WHERE project_id=#{id} AND doc_id=#{doc.id}" if span.nil?

    # when the span is specified
    doc.relations.where("denotations.begin >= ? and denotations.end <= ?", span[:begin], span[:end]).count
  end

  def json
    except_columns = %w(docs_count user_id)
    to_json(except: except_columns, methods: :maintainer)
  end

  def has_running_jobs?
    jobs.any? { |job| job.running? }
  end

  def has_waiting_jobs?
    jobs.any? { |job| job.waiting? }
  end

  def has_unfinished_jobs?
    jobs.any? { |job| job.unfinished? }
  end

  def empty?
    ProjectDoc.where(project_id: id).empty?
  end

  def has_doc?(doc)
    ProjectDoc.exists?(project_id: id, doc_id:doc.id)
  end

  def has_discontinuous_span?
    relations.where(pred: '_lexicallyChainedTo').exists?
  end

  def maintainer
    user.present? ? user.username : ''
  end

  def downloads_system_path
    "#{Rails.root}/public#{Project::DOWNLOADS_PATH}"
  end

  def annotations_tgz_filename
    "#{identifier}-annotations.tgz"
  end

  def annotations_tgz_path
    "#{Project::DOWNLOADS_PATH}" + self.annotations_tgz_filename
  end

  def annotations_tgz_system_path
    self.downloads_system_path + self.annotations_tgz_filename
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
    "#{identifier}-annotations.trig"
  end

  def graph_uri
    Rails.application.routes.url_helpers.home_url + "projects/#{self.name}"
  end

  def docs_uri
    graph_uri + '/docs'
  end

  def last_indexed_at_live(endpoint = nil)
    begin
      endpoint ||= stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
      db = Rails.application.config.ep_database
      result = endpoint.query(db, "select ?o where {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?o}")
      DateTime.parse(result.body["results"]["bindings"].first["o"]["value"])
    rescue
      nil
    end
  end

  def create_annotations_RDF(doc_ids = nil, loc = nil)
    loc ||= rdf_loc
    FileUtils.mkdir_p loc unless File.exist? loc

    rdfizer_annos = TAO::RDFizer.new(:annotations)

    graph_uri_project = self.graph_uri
    graph_uri_project_docs = self.docs_uri

    _doc_ids = if doc_ids
                 doc_ids & docs.pluck(:id)
               else
                 docs.pluck(:id)
               end

    ## begin to produce annotations_trig
    File.open(loc + '/' + annotations_rdf_filename, "w") do |f|
      _doc_ids.each_with_index do |doc_id, i|
        doc = Doc.find(doc_id)

        if i == 0
          hannotations = doc.hannotations(self, nil, nil)

          # prefixes
          preamble = rdfizer_annos.rdfize([hannotations], { only_prefixes: true })
          preamble += "@prefix pubann: <http://pubannotation.org/ontology/pubannotation.owl#> .\n"
          preamble += "@prefix oa: <http://www.w3.org/ns/oa#> .\n"
          preamble += "@prefix prov: <http://www.w3.org/ns/prov#> .\n"
          preamble += "@prefix prj: <#{Rails.application.routes.url_helpers.home_url}projects/> .\n"
          preamble += "@prefix #{name.downcase}: <#{graph_uri_project}/> .\n"
          preamble += "\n" unless preamble.empty?

          # project meta-data
          preamble += <<~HEREDOC
            <#{graph_uri_project}> rdf:type pubann:Project ;
            	rdf:type oa:Annotation ;
            	oa:has_body <#{graph_uri_project}> ;
            	oa:has_target <#{graph_uri_project_docs}> ;
            	prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .

            GRAPH <#{graph_uri_project}>
            {
          HEREDOC

          f.write(preamble)
        end

        if doc.denotations.where("denotations.project_id" => self.id).exists?
          hannotations = doc.hannotations(self, nil, nil)
          annos_ttl = rdfizer_annos.rdfize([hannotations], { with_prefixes: false })
          f.write("\t" + annos_ttl.gsub(/\n/, "\n\t").rstrip + "\n")
        end
        yield(i, doc, nil) if block_given?
      rescue => e
        message = "failure during rdfization: #{e.message}"
        if block_given?
          yield(i, doc, message) if block_given?
        else
          raise e
        end
      end
      f.write("}")
    end

  end

  def create_spans_RDF(in_collection = nil, loc = nil)
    loc ||= rdf_loc
    FileUtils.mkdir_p loc unless File.exist? loc

    rdfizer_spans = TAO::RDFizer.new(:spans)

    File.open(loc + spans_rdf_filename, "w") do |f|
      docs.each_with_index do |doc, i|
        graph_uri_doc = doc.graph_uri
        graph_uri_doc_spans = doc.graph_uri + '/spans'

        doc_spans = doc.get_denotations_hash_all(in_collection)

        if i == 0
          prefixes_ttl = rdfizer_spans.rdfize([doc_spans], { only_prefixes: true })
          prefixes_ttl += "@prefix oa: <http://www.w3.org/ns/oa#> .\n"
          prefixes_ttl += "@prefix prov: <http://www.w3.org/ns/prov#> .\n"
          prefixes_ttl += "\n" unless prefixes_ttl.empty?
          f.write(prefixes_ttl)
        end

        doc_spans_ttl = rdfizer_spans.rdfize([doc_spans], { with_prefixes: false })
        doc_spans_trig = <<~HEREDOC
          <#{graph_uri_doc_spans}> rdf:type oa:Annotation ;
          	oa:has_body <#{graph_uri_doc_spans}> ;
          	oa:has_target <#{graph_uri_doc}> ;
          	prov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .

          GRAPH <#{graph_uri_doc_spans}>
          {
          	#{doc_spans_ttl.gsub(/\n/, "\n\t")}
          }

        HEREDOC
        f.write(doc_spans_trig)
        yield(i, doc, nil) if block_given?
      rescue => e
        message = "failure during rdfization: #{e.message}"
        if block_given?
          yield(i, doc, message) if block_given?
        else
          raise e
        end
      end
    end
  end

  def rdf_needs_to_be_updated?(loc)
    tstamp_last_index = last_indexed_at(loc)
    !annotations_updated_at.nil? && (tstamp_last_index.nil? || tstamp_last_index < annotations_updated_at)
  end

  def last_indexed_at(loc = nil)
    loc ||= rdf_loc
    begin
      File.mtime(loc + '/' + annotations_rdf_filename)
    rescue
      nil
    end
  end

  def delete_index
    begin
      sd = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
      db = Rails.application.config.ep_database
      graph_uri_project = self.graph_uri
      sd.clear_db(db, graph_uri_project)
      update = <<-HEREDOC
				DELETE {<#{graph_uri_project}> prov:generatedAtTime ?generationTime .}
				WHERE  {<#{graph_uri_project}> prov:generatedAtTime ?generationTime .}
      HEREDOC
      sd.update(db, update)
    rescue
      raise "Could not delete the RDF index of this project."
    end
  end

  def self.params_from_json(json_file)
    project_attributes = JSON.parse(File.read(json_file))
    user = User.find_by!(username: project_attributes['maintainer'])
    project_params = project_attributes.select { |key| Project.attr_accessible[:default].include?(key) }
  end

  def add_docs(index)
    # Import documents that are not in the DB.
    docs_sequenced, messages = sequence index.db, index.ids

    # Tie the documents to the project.
    added_documents = tie_documents index.db, index.ids

    [added_documents, docs_sequenced, messages]
  end

  private def sequence(sourcedb, source_ids)
    source_ids_existing_in_db = Doc.where(sourcedb: sourcedb, sourceid: source_ids).pluck(:sourceid)
    ids_to_sequence = source_ids - source_ids_existing_in_db

    if ids_to_sequence.present?
      docs_sequenced, messages = Doc.sequence_and_store_docs(sourcedb, ids_to_sequence)
      [docs_sequenced.length, messages]
    else
      [0, []]
    end
  end

  private def tie_documents(sourcedb, source_ids)
    Doc.where(sourcedb: sourcedb, sourceid: source_ids)
       .where.not(sourceid: self.docs.where(sourcedb: sourcedb).select(:sourceid))
       .each { |doc| doc.projects << self }
       .length
  end

  # returns the doc added to the project
  # raise exception if nothing is added
  def add_doc!(doc)
    raise RuntimeError, "The project already has the doc: #{doc.descriptor}" if has_doc?(doc)
    doc.projects << self
    increment!(:docs_count)
    docs_stat_increment!(doc.sourcedb)
    doc
  end

  def docs_stat_increment!(sourcedb, by = 1)
    raise RuntimeError, "sourcedb is not specified." unless sourcedb.present?
    docs_stat[sourcedb] ||= 0
    docs_stat[sourcedb] += by
    update_attribute(:docs_stat, docs_stat)
  end

  def docs_stat_decrement!(sourcedb, by = 1)
    raise RuntimeError, "sourcedb is not specified." unless sourcedb.present?
    docs_stat[sourcedb] ||= 0
    docs_stat[sourcedb] -= by
    update_attribute(:docs_stat, docs_stat)
  end

  def docs_stat_update
    # count
    stat = (id == Pubann::Application.config.admin_project_id ? Doc : docs).group(:sourcedb).count

    # sort
    o = Doc::SOURCEDBS
    stat = stat.to_a.sort{|a, b| (o.index(a.first) || 99) <=> (o.index(b.first) || 99)}.to_h

    update_attribute(:docs_stat, stat)

    _docs_count = stat.values.reduce(:+) || 0
    update_attribute(:docs_count, _docs_count)

    docs_stat
  end

  def self.admin_project
    @admin_project ||= Project.find(Pubann::Application.config.admin_project_id)
  end

  def self.docs_stat
    admin_project.docs_stat
  end

  def self.docs_count
    admin_project.docs_count
  end

  def self.docs_stat_increment!(sourcedb, by = 1)
    admin_project.docs_stat_increment!(sourcedb, by)
  end

  def self.docs_stat_decrement!(sourcedb, by = 1)
    admin_project.docs_stat_decrement!(sourcedb, by)
  end

  def self.docs_count_increment!(by = 1)
    admin_project.increment!(:docs_count, by)
  end

  def self.docs_count_decrement!(by = 1)
    admin_project.increment!(:docs_count, by)
  end

  def self.docs_stat_update
    admin_project.docs_stat_update
  end

  def update_es_index
    ActiveRecord::Base.transaction do
      Doc.where("sourcedb LIKE '%#{Doc::UserSourcedbSeparator}#{user.username}' AND projects_num = 0").each do |d|
        d.__elasticsearch__.delete_document
        d.delete
      end
      # connection.exec_query("DELETE FROM docs WHERE (sourcedb LIKE '%#{Doc::UserSourcedbSeparator}#{user.username}' AND projects_num = 0)")

      Doc.__elasticsearch__.import query: -> { where(flag: true) }
      ActiveRecord::Base.connection.exec_query('UPDATE docs SET flag = false WHERE flag = true')
    end
  end

  def instantiate_hdenotations(hdenotations, docid)
    new_entries = hdenotations.map do |a|
      Denotation.new(
        hid: a[:id],
        begin: a[:span][:begin],
        end: a[:span][:end],
        obj: a[:obj],
        project_id: self.id,
        doc_id: docid,
        is_block: a[:block_p]
      )
    end
  end

  def instantiate_hblocks(hblocks, docid)
    new_entries = hblocks.map do |a|
      Block.new(
        hid: a[:id],
        begin: a[:span][:begin],
        end: a[:span][:end],
        obj: a[:obj],
        project_id: self.id,
        doc_id: docid
      )
    end
  end

  def instantiate_hrelations(hrelations, docid)
    new_entries = hrelations.map do |a|
      Relation.new(
        hid: a[:id],
        pred: a[:pred],
        subj: Denotation.find_by!(doc_id: docid, project_id: self.id, hid: a[:subj]),
        obj: Denotation.find_by!(doc_id: docid, project_id: self.id, hid: a[:obj]),
        project_id: self.id
      )
    end
  end

  def instantiate_hattributes(hattributes, docid)
    new_entries = hattributes.map do |a|
      Attrivute.new(
        hid: a[:id],
        pred: a[:pred],
        subj: Denotation.find_by(doc_id: docid, project_id: self.id, hid: a[:subj]) || Block.find_by!(doc_id: docid, project_id: self.id, hid: a[:subj]),
        obj: a[:obj],
        project_id: self.id
      )
    end
  end

  def instantiate_and_save_annotations(annotations, doc)
    ActiveRecord::Base.transaction do
      d_num = 0
      b_num = 0
      r_num = 0
      m_num = 0

      if annotations[:denotations].present?
        instances = instantiate_hdenotations(annotations[:denotations], doc.id)

        if instances.present?
          r = Denotation.import instances, validate: false
          raise "denotations import error" unless r.failed_instances.empty?
        end
        d_num = annotations[:denotations].length
      end

      if annotations[:blocks].present?
        instances = instantiate_hblocks(annotations[:blocks], doc.id)

        if instances.present?
          r = Block.import instances, validate: false
          raise "blocks import error" unless r.failed_instances.empty?
        end
        b_num = annotations[:blocks].length
      end

      if annotations[:relations].present?
        instances = instantiate_hrelations(annotations[:relations], doc.id)
        if instances.present?
          r = Relation.import instances, validate: false
          raise "relations import error" unless r.failed_instances.empty?
        end
        r_num = annotations[:denotations].length
      end

      if annotations[:attributes].present?
        instances = instantiate_hattributes(annotations[:attributes], doc.id)
        if instances.present?
          r = Attrivute.import instances, validate: false
          raise "attributes import error" unless r.failed_instances.empty?
        end
      end

      if d_num > 0 || b_num || r_num > 0
        ActiveRecord::Base.connection.exec_query("update project_docs set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num} where project_id=#{id} and doc_id=#{doc.id}")
        ActiveRecord::Base.connection.exec_query("update docs set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num} where id=#{doc.id}")
        ActiveRecord::Base.connection.exec_query("update projects set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num} where id=#{id}")
      end

      ActiveRecord::Base.connection.exec_query("update project_docs set annotations_updated_at = CURRENT_TIMESTAMP where project_id=#{id} and doc_id=#{doc.id}")
      update_annotations_updated_at
      update_updated_at
    end
  end

  # reassign ids to instances in annotations to avoid id confiction
  def reid_annotations!(annotations, doc)
    existing_ids = doc.get_annotation_hids(id)
    unless existing_ids.empty?
      id_change = {}
      if annotations.has_key?(:denotations)
        annotations[:denotations].each do |a|
          id = a[:id]
          id = Denotation.new_id while existing_ids.include?(id)
          if id != a[:id]
            id_change[a[:id]] = id
            a[:id] = id
            existing_ids << id
          end
        end

        if annotations.has_key?(:relations)
          annotations[:relations].each do |a|
            id = a[:id]
            id = Relation.new_id while existing_ids.include?(id)
            if id != a[:id]
              id_change[a[:id]] = id
              a[:id] = id
              existing_ids << id
            end
            a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
            a[:obj] = id_change[a[:obj]] if id_change.has_key?(a[:obj])
          end
        end

        if annotations.has_key?(:attributes)
          Attrivute.new_id_init
          annotations[:attributes].each do |a|
            id = a[:id]
            id = Attrivute.new_id while existing_ids.include?(id)
            if id != a[:id]
              a[:id] = id
              existing_ids << id
            end
            a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
          end
        end
      end
    end

    annotations
  end

  # annotations need to be normal
  def save_annotations!(annotations, doc, options = nil)
    raise ArgumentError, "nil document" unless doc.present?
    raise ArgumentError, "the project does not have the document" unless doc.projects.include?(self)
    options ||= {}

    return ['upload is skipped due to existing annotations'] if options[:mode] == 'skip' && doc.denotations_num > 0

    messages = AnnotationUtils.prepare_annotations!(annotations, doc, options)

    case options[:mode]
    when 'replace'
      delete_doc_annotations(doc, options[:span])
      reid_annotations!(annotations, doc) if options[:span].present?
    when 'add'
      reid_annotations!(annotations, doc)
    when 'merge'
      reid_annotations!(annotations, doc)
      base_annotations = doc.hannotations(self, options[:span], nil)
      AnnotationUtils.prepare_annotations_for_merging!(annotations, base_annotations)
    else
      reid_annotations!(annotations, doc) if options[:span].present?
    end

    instantiate_and_save_annotations(annotations, doc)

    messages
  end

  def make_request(method, url, params = nil, payload = nil)
    payload, payload_type = if payload.class == String
                              [payload, 'text/plain; charset=utf8']
                            else
                              [payload.to_json, 'application/json; charset=utf8']
                            end

    response = if method == :post && !payload.nil?
                 RestClient::Request.execute(method: method, url: url, payload: payload, max_redirects: 0, headers: { content_type: payload_type, accept: :json }, verify_ssl: false)
               else
                 RestClient::Request.execute(method: method, url: url, max_redirects: 0, headers: { params: params, accept: :json }, verify_ssl: false)
               end

    if response.code == 200
      result = begin
                 JSON.parse response, :symbolize_names => true
               rescue => e
                 raise RuntimeError, "Received a non-JSON object: [#{response}]"
               end
    else
      raise RestClient::ExceptionWithResponse.new(response)
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
    namespaces.find { |namespace| namespace['prefix'] == '_base' } if namespaces.present?
  end

  def base_uri
    namespaces_base['uri'] if namespaces_base.present?
  end

  def namespaces_prefixes
    namespaces.select { |namespace| namespace['prefix'] != '_base' } if namespaces.present?
  end

  # delete empty value hashes
  def cleanup_namespaces
    namespaces.reject! { |namespace| namespace['prefix'].blank? || namespace['uri'].blank? } if namespaces.present?
  end

  def update_updated_at
    self.update_attribute(:updated_at, DateTime.now)
  end

  def update_annotations_updated_at
    self.update_attribute(:annotations_updated_at, DateTime.now)
  end

  def clean
    denotations_num = denotations.count
    blocks_num = blocks.count
    relations_num = relations.count

    docs_count = docs.count
    update(
      docs_count: docs_count,
      denotations_num: denotations_num,
      blocks_num: blocks_num,
      relations_num: relations_num,
      annotations_count: denotations_num + blocks_num + relations_num
    )
  end

  def pretreatment_according_to(options, annotations_with_doc)
    if options[:mode] == 'replace'
      delete_doc_annotations(annotations_with_doc.doc)
    else
      case options[:mode]
      when 'add'
        annotations_with_doc.annotations.each { |a| reid_annotations!(a, doc) }
      when 'merge'
        annotations_with_doc.annotations.each { |a| reid_annotations!(a, doc) }
        base_annotations = annotations_with_doc.doc.hannotations(self, nil, nil)
        annotations_with_doc.annotations.each { |a| AnnotationUtils.prepare_annotations_for_merging!(a, base_annotations) }
      end
    end
  end

  def import_annotations_from_another_project_skip(source_project_id)
    flag_duplicate_docs_without_annotations(source_project_id)
    cnt_add_d, cnt_add_b, cnt_add_r, cnt_add_a = import_annotations_for_flagged_docs(source_project_id)
    update_numbers_for_flagged_docs(cnt_add_d, cnt_add_b, cnt_add_r, cnt_add_a)
    clear_flags
  end

  def import_annotations_from_another_project_replace(source_project_id)
    flag_duplicate_docs(source_project_id)
    cnt_del_d, cnt_del_b, cnt_del_r, cnt_del_a = delete_annotations_in_flagged_docs
    cnt_add_d, cnt_add_b, cnt_add_r, cnt_add_a = import_annotations_for_flagged_docs(source_project_id)
    update_numbers_for_flagged_docs(cnt_add_d - cnt_del_d, cnt_add_b - cnt_del_b, cnt_add_r - cnt_del_r, cnt_add_a - cnt_del_a)
    clear_flags
  end

  def import_annotations_from_another_project_add(source_project_id)
    flag_duplicate_docs(source_project_id)
    cnt_add_d, cnt_add_b, cnt_add_r, cnt_add_a = import_annotations_for_flagged_docs(source_project_id)
    update_numbers_for_flagged_docs(cnt_add_d, cnt_add_b, cnt_add_r, cnt_add_a)
    clear_flags
  end

  private def flag_duplicate_docs(another_project_id)
    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE project_docs
      SET flag = true
      WHERE project_id = #{id}
      AND doc_id IN (SELECT doc_id FROM project_docs WHERE project_id = #{another_project_id})
    SQL
  end

  private def flag_duplicate_docs_without_annotations(another_project_id)
    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE project_docs
      SET flag = true
      WHERE project_id = #{id}
      AND doc_id IN (SELECT doc_id FROM project_docs WHERE project_id = #{another_project_id})
      AND denotations_num = 0 AND blocks_num = 0
    SQL
  end

  private def clear_flags
    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE project_docs
      SET flag = false
      WHERE flag = true
    SQL
  end

  private def delete_annotations_in_flagged_docs
    count_del_denotations = ActiveRecord::Base.connection.update <<~SQL.squish
      DELETE FROM denotations
      WHERE project_id=#{id} AND EXISTS (SELECT 1 FROM project_docs WHERE denotations.doc_id = project_docs.doc_id AND project_docs.flag = true)
    SQL

    count_del_blocks = ActiveRecord::Base.connection.update <<~SQL.squish
      DELETE FROM blocks
      WHERE project_id=#{id} AND EXISTS (SELECT 1 FROM project_docs WHERE blocks.doc_id = project_docs.doc_id AND project_docs.flag = true)
    SQL

    count_del_relations = ActiveRecord::Base.connection.update <<~SQL.squish
      DELETE FROM relations
      WHERE project_id=#{id} AND EXISTS (SELECT 1 FROM project_docs WHERE relations.doc_id = project_docs.doc_id AND project_docs.flag = true)
    SQL

    count_del_attrivutes = ActiveRecord::Base.connection.update <<~SQL.squish
      DELETE FROM attrivutes
      WHERE project_id=#{id} AND EXISTS (SELECT 1 FROM project_docs WHERE attrivutes.doc_id = project_docs.doc_id AND project_docs.flag = true)
    SQL

    p [count_del_denotations, count_del_blocks, count_del_relations, count_del_attrivutes]
    p "---"

    [count_del_denotations, count_del_blocks, count_del_relations, count_del_attrivutes]
  end

  private def import_annotations_for_flagged_docs(source_project_id)
    count_add_denotations = ActiveRecord::Base.connection.update <<~SQL.squish
      INSERT INTO denotations (doc_id, project_id, hid, "begin", "end", obj, is_block, created_at, updated_at)
      SELECT doc_id, #{id}, hid, "begin", "end", obj, is_block, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM denotations
      WHERE project_id=#{source_project_id}
      AND denotations.doc_id IN (SELECT doc_id FROM project_docs WHERE flag = true)
    SQL

    count_add_blocks = ActiveRecord::Base.connection.update <<~SQL.squish
      INSERT INTO blocks (doc_id, project_id, hid, "begin", "end", obj, created_at, updated_at)
      SELECT doc_id, #{id}, hid, "begin", "end", obj, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM blocks
      WHERE project_id=#{source_project_id}
      AND blocks.doc_id IN (SELECT doc_id FROM project_docs WHERE flag = true)
    SQL

    count_add_relations = ActiveRecord::Base.connection.update <<~SQL.squish
      INSERT INTO relations (doc_id, project_id, hid, subj_id, subj_type, obj_id, obj_type, pred, created_at, updated_at)
      SELECT
        doc_id, #{id}, hid,
        CASE subj_type
          WHEN 'Denotation' THEN (SELECT id FROM denotations AS t_d WHERE t_d.hid = (SELECT hid FROM denotations AS s_d WHERE s_d.id = relations.subj_id) AND t_d.doc_id = relations.doc_id AND t_d.project_id = #{id})
          WHEN 'Block' THEN (SELECT id FROM blocks AS t_b WHERE t_b.hid = (SELECT hid FROM blocks AS s_b WHERE s_b.id = relations.subj_id) AND t_b.doc_id = relations.doc_id AND t_b.project_id = #{id})
        END,
        subj_type,
        CASE obj_type
          WHEN 'Denotation' THEN (SELECT id FROM denotations AS t_d WHERE t_d.hid = (SELECT hid FROM denotations AS s_d WHERE s_d.id = relations.obj_id) AND t_d.doc_id = relations.doc_id AND t_d.project_id = #{id})
          WHEN 'Block' THEN (SELECT id FROM blocks AS t_b WHERE t_b.hid = (SELECT hid FROM blocks AS s_b WHERE s_b.id = relations.obj_id) AND t_b.doc_id = relations.doc_id AND t_b.project_id = #{id})
        END,
        obj_type, pred, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM relations
      WHERE project_id = #{source_project_id}
      AND relations.doc_id IN (SELECT doc_id FROM project_docs WHERE flag = true)
    SQL

    count_add_attrivutes = ActiveRecord::Base.connection.update <<~SQL.squish
      INSERT INTO attrivutes (doc_id, project_id, hid, subj_id, subj_type, obj, pred, created_at, updated_at)
      SELECT
        doc_id, #{id}, hid,
        CASE subj_type
          WHEN 'Denotation' THEN (SELECT id FROM denotations AS t_d WHERE t_d.hid = (SELECT hid FROM denotations AS s_d WHERE s_d.id = attrivutes.subj_id) AND t_d.doc_id = attrivutes.doc_id AND t_d.project_id = #{id})
          WHEN 'Block' THEN (SELECT id FROM blocks AS t_b WHERE t_b.hid = (SELECT hid FROM blocks AS s_b WHERE s_b.id = attrivutes.subj_id) AND t_b.doc_id = attrivutes.doc_id AND t_b.project_id = #{id})
          WHEN 'Relation' THEN (SELECT id FROM relations AS t_r WHERE t_r.hid = (SELECT hid FROM relations AS s_r WHERE s_r.id = attrivutes.subj_id) AND t_r.doc_id = attrivutes.doc_id AND t_r.project_id = #{id})
        END,
        subj_type, obj, pred, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM attrivutes
      WHERE project_id = #{source_project_id}
      AND attrivutes.doc_id IN (SELECT doc_id FROM project_docs WHERE flag = true)
    SQL

    [count_add_denotations, count_add_blocks, count_add_relations, count_add_attrivutes]
  end

  private def update_numbers_for_flagged_docs(count_diff_denotations, count_diff_blocks, count_diff_relations, count_diff_attrivutes)
    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE project_docs
      SET
        denotations_num = (SELECT count(*) FROM denotations WHERE denotations.doc_id = project_docs.id AND denotations.project_id = project_docs.project_id),
        blocks_num = (SELECT count(*) FROM blocks WHERE blocks.doc_id = project_docs.id AND blocks.project_id = project_docs.project_id),
        relations_num = (SELECT count(*) FROM relations WHERE relations.doc_id = project_docs.id AND relations.project_id = project_docs.project_id)
      WHERE flag = true
    SQL

    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE docs
      SET
        denotations_num = (SELECT count(*) FROM denotations WHERE denotations.doc_id = docs.id),
        blocks_num = (SELECT count(*) FROM blocks WHERE blocks.doc_id = docs.id),
        relations_num = (SELECT count(*) FROM relations WHERE relations.doc_id = docs.id)
      WHERE EXISTS (SELECT 1 FROM project_docs WHERE project_docs.id = docs.id AND project_docs.flag = true)
    SQL

    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE projects
      SET
        denotations_num = denotations_num + #{count_diff_denotations},
        blocks_num = blocks_num + #{count_diff_blocks},
        relations_num = relations_num + #{count_diff_relations}
      WHERE id=#{id}
    SQL
  end

  def import_docs_from_another_project(source_project_id)
    count = 0
    ActiveRecord::Base.transaction do
      count = ActiveRecord::Base.connection.update <<~SQL.squish
            INSERT INTO project_docs (project_id, doc_id, flag)
            SELECT #{id}, doc_id, true
            FROM project_docs
            WHERE project_id=#{source_project_id}
            ON CONFLICT
            DO NOTHING
          SQL

      ActiveRecord::Base.connection.update <<~SQL.squish
        UPDATE docs
        SET projects_num = projects_num + 1
        WHERE EXISTS (SELECT 1 FROM project_docs WHERE flag=true AND project_docs.doc_id=docs.id)
      SQL

      ActiveRecord::Base.connection.update <<~SQL.squish
        UPDATE project_docs
        SET flag = false
        WHERE flag = true
      SQL

      docs_stat_update
    end

    count
  end

  def delete_doc_annotations(doc, span = nil)
    if span.present?
      Denotation.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', self.id, doc.id, span[:begin], span[:end]).destroy_all
      Block.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', self.id, doc.id, span[:begin], span[:end]).destroy_all
    else
      ActiveRecord::Base.transaction do
        d_num = ActiveRecord::Base.connection.update("delete from denotations where project_id=#{self.id} AND doc_id=#{doc.id}")
        b_num = ActiveRecord::Base.connection.update("delete from blocks where project_id=#{self.id} AND doc_id=#{doc.id}")
        r_num = ActiveRecord::Base.connection.update("delete from relations where project_id=#{self.id} AND doc_id=#{doc.id}")
        a_num = ActiveRecord::Base.connection.update("delete from attrivutes where project_id=#{self.id} AND doc_id=#{doc.id}")

        if d_num > 0 || b_num > 0
          ActiveRecord::Base.connection.update("update project_docs set denotations_num = 0, blocks_num = 0, relations_num = 0, annotations_updated_at = CURRENT_TIMESTAMP where project_id=#{id} and doc_id=#{doc.id}")
          ActiveRecord::Base.connection.update("update docs set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num} where id=#{doc.id}")
          ActiveRecord::Base.connection.update("update projects set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num} where id=#{id}")

          update_annotations_updated_at
          update_updated_at
        end
      end
    end
  end

  def delete_annotations
    if denotations_num > 0 
      ActiveRecord::Base.transaction do
        # destroy annotations
        a_num = ActiveRecord::Base.connection.update("DELETE FROM attrivutes WHERE project_id = #{id}")
        r_num = ActiveRecord::Base.connection.update("DELETE FROM relations WHERE project_id = #{id}")
        b_num = ActiveRecord::Base.connection.update("DELETE FROM blocks WHERE project_id = #{id}")
        d_num = ActiveRecord::Base.connection.update("DELETE FROM denotations WHERE project_id = #{id}")

        # update annotation counts for the project
        ActiveRecord::Base.connection.update("UPDATE projects SET denotations_num = 0, blocks_num=0, relations_num=0, annotations_updated_at = CURRENT_TIMESTAMP WHERE id=#{id}")

        # update annotation counts for each doc within the project
        ActiveRecord::Base.connection.update("UPDATE project_docs SET denotations_num = 0, blocks_num = 0, relations_num = 0, annotations_updated_at = CURRENT_TIMESTAMP WHERE project_id=#{id}")

        # update annotation counts for each doc
        ActiveRecord::Base.connection.update("UPDATE docs SET denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num} WHERE EXISTS (SELECT 1 FROM project_docs WHERE project_id=#{id} AND doc_id=docs.id)")

        update_annotations_updated_at
        update_updated_at
      end
    end
  end

  def delete_doc(doc)
    raise RuntimeError, "The project does not include the document." unless self.docs.include?(doc)
    delete_doc_annotations(doc)
    doc.projects.delete(self)

    decrement!(:docs_count)
    docs_stat_decrement!(doc.sourcedb)

    doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{user.username}") && doc.projects_num == 0
  end

  def delete_docs
    if docs.exists?
      ActiveRecord::Base.transaction do
        delete_annotations

        # update project counts for each doc
        ActiveRecord::Base.connection.update("UPDATE docs SET projects_num = projects_num - 1 WHERE EXISTS (SELECT 1 FROM project_docs WHERE project_docs.project_id = #{id} AND project_docs.doc_id = docs.id)")

        # delete docs from the project
        ActiveRecord::Base.connection.delete("DELETE FROM project_docs WHERE project_id = #{id}")

        docs_stat_update

        Annotation.delete_orphan_annotations
        Doc.delete_orphan_docs_of_user_sourcedb
      end
    end
  end

  def destroy!
    # delete jobs (with messages)
    Job.batch_destroy_unless_running(self)
    jobs.each {|job| raise 'There is a running job within this project.' if job.running?}

    # delete docs (with annotations)
    delete_docs

    # delete self
    self.delete
  end

  private

  def spans_rdf_filename
    "#{identifier}-spans.trig"
  end

  def identifier
    name.gsub(' ', '_')
  end

  def rdf_loc
    Rails.application.config.system_path_rdf + "projects/#{identifier}-rdf/"
  end
end
