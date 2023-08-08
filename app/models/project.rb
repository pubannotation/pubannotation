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
  has_many :relations, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :attrivutes, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
  has_many :modifications, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
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
    return doc.subcatrels.where(project_id: self.id).count if span.nil?

    # when the span is specified
    doc.subcatrels.where("denotations.begin >= ? and denotations.end <= ?", span[:begin], span[:end]).count
  end

  def get_modifications_count(doc = nil, span = nil)
    return self.modifications_num if doc.nil?
    return doc.catmods.where(project_id: self.id).count + doc.subcatrelmods.where(project_id: self.id).count if span.nil?

    # when the span is specified
    # ToDo: check modificaitons of relations
    doc.catmods.where("denotations.begin >= ? and denotations.end <= ?", span[:begin], span[:end]).count
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

  def has_doc?
    ProjectDoc.exists?(project_id: id)
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
          hannotations = doc.hannotations(self)

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
          hannotations = doc.hannotations(self)
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

  def add_docs(sourcedb, source_ids)
    # Import documents that are not in the DB.
    docs_sequenced, messages = sequence sourcedb, source_ids

    # Tie the documents to the project.
    added_documents = tie_documents sourcedb, source_ids

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
  # returns nil if nothing is added
  def add_doc(sourcedb, sourceid)
    doc = Doc.find_by(sourcedb: sourcedb, sourceid: sourceid)
    unless doc.present?
      new_docs, messages = Doc.sequence_and_store_docs(sourcedb, [sourceid])
      unless new_docs.present?
        message = messages.map do |m|
          if m.class == Hash
            m[:body]
          else
            m
          end
        end.join("\n")
        raise RuntimeError, "Failed to get the document: #{message}"
      end
      doc = new_docs.first
    end
    return nil if self.docs.include?(doc)
    doc.projects << self
    doc
  end

  def delete_doc(doc)
    raise RuntimeError, "The project does not include the document." unless self.docs.include?(doc)
    delete_doc_annotations(doc)
    doc.projects.destroy(self)
    doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{user.username}") && doc.projects_num == 0
  end

  def delete_docs
    ActiveRecord::Base.transaction do
      delete_annotations if denotations_num > 0

      if docs.exists?
        ActiveRecord::Base.connection.exec_query(
          "
						UPDATE docs
						SET projects_num = projects_num - 1, flag = true
						WHERE docs.id
						IN (
							SELECT project_docs.doc_id
							FROM project_docs
							WHERE project_docs.project_id = #{id}
						)
					"
        )
        ActiveRecord::Base.connection.exec_query("DELETE FROM project_docs WHERE project_id = #{id}")
      end
    end
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

  def instantiate_hmodifications(hmodifications, docid)
    new_entries = hmodifications.map do |a|

      obj = Denotation.find_by!(doc_id: docid, project_id: self.id, hid: a[:obj])
      if obj.nil?
        doc = Doc.find(docid)
        doc.subcatrels.find_by!(project_id: self.id, hid: a[:obj])
      end
      raise ArgumentError, "Invalid object of modification: #{a[:id]}" if obj.nil?

      Modification.new(
        hid: a[:id],
        pred: a[:pred],
        obj: obj,
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

      if annotations[:modifications].present?
        instances = instantiate_hmodifications(annotations[:modifications], doc.id)
        if instances.present?
          r = Modification.import instances, validate: false
          raise "modifications import error" unless r.failed_instances.empty?
        end
        m_num = annotations[:modifications].length
      end

      if d_num > 0 || b_num || r_num > 0 || m_num > 0
        ActiveRecord::Base.connection.exec_query("update project_docs set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where project_id=#{id} and doc_id=#{doc.id}")
        ActiveRecord::Base.connection.exec_query("update docs set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where id=#{doc.id}")
        ActiveRecord::Base.connection.exec_query("update projects set denotations_num = denotations_num + #{d_num}, blocks_num = blocks_num + #{b_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where id=#{id}")
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

        if annotations.has_key?(:modifications)
          annotations[:modifications].each do |a|
            id = a[:id]
            id = Modification.new_id while existing_ids.include?(id)
            if id != a[:id]
              a[:id] = id
              existing_ids << id
            end
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

    messages = Annotation.prepare_annotations!(annotations, doc, options)

    case options[:mode]
    when 'replace'
      delete_doc_annotations(doc, options[:span])
      reid_annotations!(annotations, doc) if options[:span].present?
    when 'add'
      reid_annotations!(annotations, doc)
    when 'merge'
      reid_annotations!(annotations, doc)
      base_annotations = doc.hannotations(self, options[:span])
      Annotation.prepare_annotations_for_merging!(annotations, base_annotations)
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

  def delete_annotations
    ActiveRecord::Base.transaction do
      Modification.where(project_id: self.id).delete_all
      Relation.where(project_id: self.id).delete_all
      Denotation.where(project_id: self.id).delete_all

      ActiveRecord::Base.connection.exec_query("update project_docs set denotations_num = 0, relations_num = 0, modifications_num = 0, annotations_updated_at = NULL where project_id=#{id}")

      if docs.count < 1000000
        ActiveRecord::Base.connection.exec_query("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})")
        ActiveRecord::Base.connection.exec_query("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if relations_num > 0
        ActiveRecord::Base.connection.exec_query("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id)) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if modifications_num > 0
      else
        ActiveRecord::Base.connection.exec_query("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id)")
        ActiveRecord::Base.connection.exec_query("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id)") if relations_num > 0
        ActiveRecord::Base.connection.exec_query("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id))") if modifications_num > 0
      end

      ActiveRecord::Base.connection.exec_query("update projects set denotations_num = 0, relations_num=0, modifications_num=0 where id=#{id}")

      update_annotations_updated_at
      update_updated_at
    end
  end

  def delete_doc_annotations(doc, span = nil)
    if span.present?
      Denotation.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', self.id, doc.id, span[:begin], span[:end]).destroy_all
      Block.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', self.id, doc.id, span[:begin], span[:end]).destroy_all
    else
      denotations = doc.denotations.where(project_id: self.id)
      d_num = denotations.length

      blocks = doc.blocks.where(project_id: self.id)
      b_num = blocks.length

      if d_num > 0 || b_num > 0
        modifications = doc.catmods.where(project_id: self.id) + doc.subcatrelmods.where(project_id: self.id)
        m_num = modifications.length

        relations = doc.subcatrels.where(project_id: self.id)
        r_num = relations.length

        attributes = doc.denotation_attributes.where(project_id: self.id)
        a_num = attributes.length

        ActiveRecord::Base.transaction do
          Modification.delete(modifications) if m_num > 0
          Relation.delete(relations) if r_num > 0
          Attrivute.delete(attributes) if a_num > 0
          Block.delete(blocks)
          Denotation.delete(denotations)

          # ActiveRecord::Base.establish_connection
          ActiveRecord::Base.connection.exec_query("update project_docs set denotations_num = 0, blocks_num = 0, relations_num = 0, modifications_num = 0, annotations_updated_at = NULL where project_id=#{id} and doc_id=#{doc.id}")
          ActiveRecord::Base.connection.exec_query("update docs set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num}, modifications_num = modifications_num - #{m_num} where id=#{doc.id}")
          ActiveRecord::Base.connection.exec_query("update projects set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num}, modifications_num = modifications_num - #{m_num} where id=#{id}")

          update_annotations_updated_at
          update_updated_at
        end
      end
    end
  end

  def update_updated_at
    self.update_attribute(:updated_at, DateTime.now)
  end

  def update_annotations_updated_at
    self.update_attribute(:annotations_updated_at, DateTime.now)
  end

  def clean
    denotations_num = denotations.count
    relations_num = relations.count
    modifications_num = modifications.count

    docs_count = docs.count
    update(
      docs_count: docs_count,
      denotations_num: denotations_num,
      relations_num: relations_num,
      modifications_num: relations_num,
      annotations_count: denotations_num + relations_num + modifications_num
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
        base_annotations = annotations_with_doc.doc.hannotations(self)
        annotations_with_doc.annotations.each { |a| Annotation.prepare_annotations_for_merging!(a, base_annotations) }
      end
    end
  end

  private

  def spans_rdf_filename
    "#{identifier}-spans.trig"
  end

  def annotations_rdf_filename
    "#{identifier}-annotations-rdf.zip"
  end

  def identifier
    name.gsub(' ', '_')
  end

  def rdf_loc
    Rails.application.config.system_path_rdf + "projects/#{identifier}-rdf/"
  end
end
