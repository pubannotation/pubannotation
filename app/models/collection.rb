class Collection < ActiveRecord::Base
	belongs_to :user
	has_many :collection_projects, dependent: :destroy
	has_many :projects, through: :collection_projects
	has_many :queries, as: :organization, :dependent => :destroy
	has_many :jobs, as: :organization, :dependent => :destroy
	validates :name, presence: true, uniqueness: true

	scope :accessible, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where('collections.accessibility = ? OR collections.user_id =?', 1, current_user.id)
			end
		else
			where(accessibility: [1, 3])
		end
	}

	scope :editable, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where('collections.user_id =?', current_user.id)
			end
		end
	}

	scope :addable, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where('collections.user_id = ? OR collections.is_open = TRUE', current_user.id)
			end
		end
	}

	scope :sharedtasks, -> { where(is_sharedtask: true) }
	scope :no_sharedtasks, -> { where(is_sharedtask: false) }

	scope :top_recent, -> { order('collections.updated_at DESC').limit(10) }

	def editable?(current_user)
		current_user.present? && (current_user.root? || current_user == user)
	end

	def destroyable?(current_user)
		current_user.present? && (current_user.root? || current_user == user)
	end

	def primary_projects
		Project.joins(:collection_projects).where("collection_projects.collection_id": id, "collection_projects.is_primary": true)
	end

	def secondary_projects
		Project.joins(:collection_projects).where("collection_projects.collection_id": id, "collection_projects.is_secondary": true)
	end

	def active_projects
		Project.joins(:collection_projects).where("collection_projects.collection_id": id).where("collection_projects.is_primary=? OR collection_projects.is_secondary=?", true, true)
	end

	def primary_docids
		[].union(*self.primary_projects.collect{|project| project.docs.pluck(:id)})
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

	def identifier
		name.gsub(' ', '_')
	end

	def self.rdf_loc
		Rails.application.config.system_path_rdf + 'collections/'
	end

	def rdf_dirname
		identifier + '-rdf'
	end

	def rdf_new_dirname
		rdf_dirname + '--new'
	end

	def rdf_zipname
		identifier + '-rdf.zip'
	end

	def rdf_dirpath
		@rdf_dirpath ||= Collection.rdf_loc + rdf_dirname
	end

	def rdf_new_dirpath
		@rdf_new_dirpath||= Collection.rdf_loc + rdf_new_dirname
	end

	def rdf_zippath
		@rdf_zippath ||= Collection.rdf_loc + rdf_zipname
	end

	def spans_rdf_filename
		"#{identifier}-spans.trig"
	end

	def create_spans_RDF(loc = nil)
		loc ||= Collection.rdf_loc + rdf_dirname

		project_ids = active_projects.pluck(:id)
		doc_ids = [].union(*self.primary_projects.collect{|project| project.docs.pluck(:id)})

		if @job
			prepare_progress_record(doc_ids.count)
		end

		File.open(loc + '/' + spans_rdf_filename, "w") do |f|
			doc_ids.each_with_index do |doc_id, i|
				doc = Doc.find(doc_id)

				doc_spans_trig = if i == 0
					doc.get_spans_rdf(project_ids, {with_prefixes: true})
				else
					doc.get_spans_rdf(project_ids, {with_prefixes: false})
				end

				f.write("\n") unless i == 0
				f.write(doc_spans_trig)
			rescue => e
				message = "failure during rdfization: #{e.message}"
				if block_given?
					yield(i, doc, message) if block_given?
				else
					raise e
				end
			ensure
				yield(i, doc, nil) if block_given?
			end
		end
	end

	def create_RDF_zip(encoding = nil)
		puts `cd #{Collection.rdf_loc}; zip #{rdf_zipname} #{rdf_dirname}/*`
	end

	def last_indexed_at
		begin
			File.mtime(rdf_dirpath)
		rescue
			nil
		end
	end

	def last_indexed_at_live(endpoint = nil)
		nil
	end

end
