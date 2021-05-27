require 'fileutils'

class Collection < ActiveRecord::Base
	belongs_to :user
	has_many :collection_projects, dependent: :destroy
	has_many :projects, through: :collection_projects
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

	def annotations_rdf_dirpath
		@annotations_rdf_dirpath ||= Rails.application.config.system_path_rdf + 'collections/' + "#{name.gsub(' ', '_')}"
	end

	def create_spans_RDF
		pprojects = self.primary_projects
		unless pprojects.empty?
			pproject = pprojects.first

			# pproject.create_spans_RDF

			# dj = CreateSpansRdfJob.new(pproject)
			# dj.perform()

			delayed_job = Delayed::Job.enqueue CreateSpansRdfJob.new(pproject, self), queue: :general
			job = pproject.jobs.create({name:"Create Spans RDF - #{pproject.name}", delayed_job_id:delayed_job.id})
			sleep(1) until job.finished_live?

			FileUtils.ln_sf(pproject.spans_trig_filepath, annotations_rdf_dirpath)
		end
	end

	def create_annotations_RDF(forced = false)
		FileUtils.mkdir_p annotations_rdf_dirpath unless File.exists? annotations_rdf_dirpath
		FileUtils.rm_f Dir.glob("#{annotations_rdf_dirpath}/*")

		projects.indexable.each_with_index do |project, i|
			begin
				if forced || project.rdf_needs_to_be_updated?
					delayed_job = Delayed::Job.enqueue CreateAnnotationRdfJob.new(project), queue: :general
					job = project.jobs.create({name:"Create Annotation RDF - #{project.name}", delayed_job_id:delayed_job.id})
					sleep(1) until job.finished_live?
				end
				FileUtils.ln_sf(project.annotations_trig_filepath, annotations_rdf_dirpath)
				yield(i, nil) if block_given?
			rescue => e
				message = "failure during rdfization of #{project.name}: #{e.message}"
				if block_given?
					yield(i, message) if block_given?
				else
					raise e
				end
			end
		end
	end

end
