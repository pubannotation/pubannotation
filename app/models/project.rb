class Project < ActiveRecord::Base
	include ApplicationHelper
	include AnnotationsHelper
	DOWNLOADS_PATH = "/downloads/"

	before_validation :cleanup_namespaces
	after_validation :user_presence
	serialize :namespaces
	belongs_to :user
	belongs_to :annotator
	has_many :collection_projects, dependent: :destroy
	has_many :collections, through: :collection_projects
	has_many :project_docs, dependent: :destroy
	has_many :docs, through: :project_docs
	has_many :queries

	has_many :evaluations, foreign_key: 'study_project_id'
	has_many :evaluatees, class_name: 'Evaluation', foreign_key: 'reference_project_id'

	attr_accessible :name, :description, :author, :anonymize, :license, :status, :accessibility, :reference,
									:sample, :rdfwriter, :xmlwriter, :bionlpwriter, :sparql_ep,
									:textae_config, :annotator_id,
									:annotations_zip_downloadable, :namespaces, :process,
									:docs_count, :denotations_num, :relations_num, :modifications_num, :annotations_count
	has_many :denotations, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
	has_many :relations, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
	has_many :attrivutes, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
	has_many :modifications, :dependent => :destroy, after_add: [:update_annotations_updated_at, :update_updated_at]
	has_many :associate_maintainers, :dependent => :destroy
	has_many :associate_maintainer_users, :through => :associate_maintainers, :source => :user, :class_name => 'User'
	has_many :jobs, as: :organization, :dependent => :destroy
	validates :name, :presence => true, :length => {:minimum => 5, :maximum => 40}, uniqueness: true
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

	scope :indexable, where(accessibility: 1, status: [1, 2, 3, 8])

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

	def self.statistics
		counts = Project.where(accessibility: 1).group(:status).group(:process).count
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
		return self.denotations_num if doc.nil?
		doc.get_denotations_count(id, span)
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

	def annotations_collection(encoding = nil)
		if self.docs.present?
			self.docs.collect{|doc| doc.set_ascii_body if encoding == 'ascii'; doc.hannotations(self, nil, nil, {sort:true})}
		else
			[]
		end
	end

	def json
		except_columns = %w(docs_count user_id)
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

	def has_unfinished_jobs?
		jobs.each{|job| return true if job.unfinished?}
		return false
	end

	def has_doc?
		ProjectDoc.exists?(project_id: id)
	end

	def has_discontinuous_span?
		relations.where(pred: '_lexicallyChainedTo').exists?
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

	def annotations_filename
		"annotations-#{self.name.gsub(' ', '_')}"
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

	def annotations_rdf_dirname
		"#{self.name.gsub(' ', '_')}-annotations-rdf"
	end

	def annotations_rdf_dir_path
		Rails.application.config.system_path_rdf + self.annotations_rdf_dirname
	end

	def annotations_rdf_filename
		"#{self.name.gsub(' ', '_')}-annotations-rdf.zip"
	end

	def annotations_trig_filepath
		Rails.application.config.system_path_rdf + 'projects/' + "#{name.gsub(' ', '_')}-annotations.trig"
	end

	def spans_trig_filepath
		Rails.application.config.system_path_rdf + 'projects/' + "#{name.gsub(' ', '_')}-spans.trig"
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

	def last_indexed_at
		begin
			File.mtime(annotations_trig_filepath)
		rescue
			nil
		end
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

	def create_annotations_RDF
		rdfizer_annos = TAO::RDFizer.new(:annotations)

		graph_uri_project = self.graph_uri
		graph_uri_project_docs = self.docs_uri

		## begin to produce annotations_trig
		File.open(annotations_trig_filepath, "w") do |f|
			docs.each_with_index do |doc, i|
				if doc.denotations.where("denotations.project_id" => self.id).exists?
					hannotations = doc.hannotations(self)

					if i == 0
						# prefixes
						preamble  = rdfizer_annos.rdfize([hannotations], {only_prefixes: true})
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

					annos_ttl = rdfizer_annos.rdfize([hannotations], {with_prefixes: false})
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

	def create_spans_RDF(in_class = nil)
		rdfizer_spans = TAO::RDFizer.new(:spans)
		graph_uri_project = self.graph_uri

		File.open(spans_trig_filepath, "w") do |f|
			docs.each_with_index do |doc, i|
				graph_uri_doc = doc.graph_uri
				graph_uri_doc_spans = doc.graph_uri + '/spans'

				doc_spans = doc.get_denotations_hash_all(in_class)

				if i == 0
					prefixes_ttl = rdfizer_spans.rdfize([doc_spans], {only_prefixes: true})
					prefixes_ttl += "@prefix oa: <http://www.w3.org/ns/oa#> .\n"
					prefixes_ttl += "@prefix prov: <http://www.w3.org/ns/prov#> .\n"
					prefixes_ttl += "\n" unless prefixes_ttl.empty?
					f.write(prefixes_ttl)
				end

				doc_spans_ttl = rdfizer_spans.rdfize([doc_spans], {with_prefixes: false})
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

	def rdf_needs_to_be_updated?
		!annotations_updated_at.nil? && (last_indexed_at.nil? || last_indexed_at < annotations_updated_at)
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

	def post_rdf_stardog(ttl, project_name = nil, initp = false)
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

	def add_docs(sourcedb, _sourceids)
		sourceids = _sourceids.uniq
		ids_in_pa = Doc.where(sourcedb:sourcedb, sourceid:sourceids).pluck(:sourceid).uniq
		ids_in_pj = ids_in_pa & docs.pluck(:sourceid).uniq

		ids_to_add = ids_in_pa - ids_in_pj
		docs_to_add = Doc.where(sourcedb:sourcedb, sourceid:ids_to_add)

		ids_to_sequence = sourceids - ids_in_pa
		docs_sequenced, messages = ids_to_sequence.present? ? Doc.sequence_and_store_docs(sourcedb, ids_to_sequence) : [[], []]

		docs_to_add += docs_sequenced

		docs_to_add.each{|doc| doc.projects << self}
		num_docs_existed = ids_in_pj.length

		# return [num_added, num_sequenced, num_existed, messages]
		[docs_to_add.length, docs_sequenced.length, ids_in_pj.length, messages]
	end

	# returns the doc added to the project
	# returns nil if nothing is added
	def add_doc(sourcedb, sourceid)
		doc = Doc.find_by_sourcedb_and_sourceid(sourcedb, sourceid)
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
		doc.projects.delete(self)
		doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{user.username}") && doc.projects_num == 0
	end

	def delete_docs
		ActiveRecord::Base.transaction do
			delete_annotations if denotations_num > 0

			if docs.exists?
				connection.exec_query(
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
				connection.exec_query("DELETE FROM project_docs WHERE project_id = #{id}")
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

			Doc.__elasticsearch__.import query: -> {where(flag:true)}
			connection.exec_query('UPDATE docs SET flag = false WHERE flag = true')
		end
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
					:source_url => :source
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
		res = ActiveRecord::Base.transaction do
			d_num = 0
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

			if d_num > 0 || r_num > 0 || m_num > 0
				connection.exec_query("update project_docs set denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where project_id=#{id} and doc_id=#{doc.id}")
				connection.exec_query("update docs set denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where id=#{doc.id}")
				connection.exec_query("update projects set denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} where id=#{id}")
			end

			connection.exec_query("update project_docs set annotations_updated_at = CURRENT_TIMESTAMP where project_id=#{id} and doc_id=#{doc.id}")
			update_annotations_updated_at
			update_updated_at
		end
	end

	def instantiate_and_save_annotations_collection(annotations_collection)
		ActiveRecord::Base.transaction do

			# collect statistics
			d_stat, r_stat, a_stat, m_stat = Hash.new(0), Hash.new(0), Hash.new(0), Hash.new(0)

			# record document id
			annotations_collection.each do |ann|
				ann[:docid] = Doc.select(:id).where(sourcedb:ann[:sourcedb], sourceid:ann[:sourceid]).first.id
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
				connection.exec_query("UPDATE project_docs SET denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} WHERE project_id=#{id} AND doc_id=#{did}")
				connection.execute("UPDATE docs SET denotations_num = denotations_num + #{d_num}, relations_num = relations_num + #{r_num}, modifications_num = modifications_num + #{m_num} WHERE id=#{did}")
			end

			annotations_collection.each do |ann|
				connection.exec_query("UPDATE project_docs SET annotations_updated_at = CURRENT_TIMESTAMP WHERE project_id=#{id} AND doc_id=#{ann[:docid]}")
			end

			connection.execute("UPDATE projects SET denotations_num = denotations_num + #{d_stat_all}, relations_num = relations_num + #{r_stat_all}, modifications_num = modifications_num + #{m_stat_all} WHERE id=#{id}")

			update_annotations_updated_at
			update_updated_at
		end
	end

	def reid_annotations!(annotations, doc)
		aids_background = doc.get_annotation_hids(id)
		unless aids_background.empty?
			id_change = {}
			if annotations.has_key?(:denotations)
				annotations[:denotations].each do |a|
					id = a[:id]
					id = Denotation.new_id while aids_background.include?(id)
					if id != a[:id]
						id_change[a[:id]] = id
						a[:id] = id
						aids_background << id
					end
				end

				if annotations.has_key?(:relations)
					annotations[:relations].each do |a|
						id = a[:id]
						id = Relation.new_id while aids_background.include?(id)
						if id != a[:id]
							id_change[a[:id]] = id
							a[:id] = id
							aids_background << id
						end
						a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
						a[:obj] = id_change[a[:obj]] if id_change.has_key?(a[:obj])
					end
				end

				if annotations.has_key?(:attributes)
					annotations[:attributes].each do |a|
						id = a[:id]
						id = Attrivute.new_id while aids_background.include?(id)
						if id != a[:id]
							a[:id] = id
							aids_background << id
						end
						a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
					end
				end

				if annotations.has_key?(:modifications)
					annotations[:modifications].each do |a|
						id = a[:id]
						id = Modification.new_id while aids_background.include?(id)
						if id != a[:id]
							a[:id] = id
							aids_background << id
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

	# It assumes that
	# - annotations are already normal, and
	# - documents exist in the database
	def store_annotations_collection(annotations_collection, options)
		messages = []
		num_skipped = 0

		# To find the doc for each annotation object
		annotations_collection_with_doc = annotations_collection.collect do |annotations|
			sourcedb, sourceid = if annotations.is_a? Array
				a = annotations.first
				[a[:sourcedb], a[:sourceid]]
			else
				[annotations[:sourcedb], annotations[:sourceid]]
			end

			docs = Doc.where(sourcedb:sourcedb, sourceid:sourceid)

			if docs.count == 1
				[annotations, docs.first]
			else
				error_message = if docs.empty?
					'Document does not exist.'
				else
					'Multiple entries of the document.'
				end
				messages << {sourcedb:sourcedb, sourceid:sourceid, body:error_message[0 .. 250]}
				[annotations, nil]
			end
		end.reject{|e| e[1].nil?}

		num_annotations_with_doc = annotations_collection_with_doc.count

		# skip option
		if options[:mode] == 'skip'
			annotations_collection_with_doc.select! do |annotations, doc|
				ProjectDoc.where(project_id:id, doc_id:doc.id).pluck(:denotations_num).first == 0
			end
			num_skipped = num_annotations_with_doc - annotations_collection_with_doc.count
		end

		annotations_collection_with_doc.each do |annotations, doc|
			messages += Annotation.prepare_annotations!(annotations, doc, options)
		end

		aligned_collection = []
		annotations_collection_with_doc.each do |annotations, doc|
			ann = annotations.is_a?(Array) ? annotations : [annotations]

			if options[:mode] == 'replace'
				delete_doc_annotations(doc)
			else
				case options[:mode]
				when 'add'
					ann.each{|a| reid_annotations!(a, doc)}
				when 'merge'
					ann.each{|a| reid_annotations!(a, doc)}
					base_annotations = doc.hannotations(self)
					ann.each{|a| Annotation.prepare_annotations_for_merging!(a, base_annotations)}
				end
			end

			aligned_collection += ann
		rescue StandardError => e
			messages << {sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: e.message[0 .. 250]}
		end

		messages << {body: "Uploading for #{num_skipped} documents were skipped due to existing annotations."} if num_skipped > 0

		instantiate_and_save_annotations_collection(aligned_collection) if aligned_collection.present?

		messages
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
				docs.map{|doc| doc.hannotations(self).select{|k, v| [:text, :sourcedb, :sourceid].include? k}}
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
		ActiveRecord::Base.transaction do
			Modification.delete_all(project_id:self.id)
			Relation.delete_all(project_id:self.id)
			Denotation.delete_all(project_id:self.id)

			connection.exec_query("update project_docs set denotations_num = 0, relations_num = 0, modifications_num = 0, annotations_updated_at = NULL where project_id=#{id}")

			if docs.count < 1000000
				connection.exec_query("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})")
				connection.exec_query("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if relations_num > 0
				connection.exec_query("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id)) WHERE docs.id IN (SELECT docs.id FROM docs INNER JOIN project_docs ON docs.id = project_docs.doc_id WHERE project_docs.project_id = #{id})") if modifications_num > 0
			else
				connection.exec_query("update docs set denotations_num = (select count(*) from denotations where denotations.doc_id = docs.id)")
				connection.exec_query("update docs set relations_num = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id)") if relations_num > 0
				connection.exec_query("update docs set modifications_num = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id))") if modifications_num > 0
			end

			connection.exec_query("update projects set denotations_num = 0, relations_num=0, modifications_num=0 where id=#{id}")

			update_annotations_updated_at
			update_updated_at
		end
	end

	def delete_doc_annotations(doc, span = nil)
		if span.present?
			Denotation.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', self.id, doc.id, span[:begin], span[:end]).destroy_all
		else
			denotations = doc.denotations.where(project_id: self.id)
			d_num = denotations.length

			if d_num > 0
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
					Denotation.delete(denotations)

					# ActiveRecord::Base.establish_connection
					connection.exec_query("update project_docs set denotations_num = 0, relations_num = 0, modifications_num = 0, annotations_updated_at = NULL where project_id=#{id} and doc_id=#{doc.id}")
					connection.exec_query("update docs set denotations_num = denotations_num - #{d_num}, relations_num = relations_num - #{r_num}, modifications_num = modifications_num - #{m_num} where id=#{doc.id}")
					connection.exec_query("update projects set denotations_num = denotations_num - #{d_num}, relations_num = relations_num - #{r_num}, modifications_num = modifications_num - #{m_num} where id=#{id}")

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
		update_attributes(
			docs_count: docs_count,
			denotations_num: denotations_num,
			relations_num: relations_num,
			modifications_num: relations_num,
			annotations_count: denotations_num + relations_num + modifications_num
		)
	end
end
