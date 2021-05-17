require 'fileutils'

class Collection < ActiveRecord::Base
	belongs_to :user
	attr_accessible :description, :name, :reference,
									:is_sharedtask, :accessibility, :is_open, :sparql_ep
	has_many :collection_projects, dependent: :destroy
	has_many :projects, through: :collection_projects
	has_many :jobs, as: :organization, :dependent => :destroy

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

	scope :sharedtasks, where(is_sharedtask: true)
	scope :no_sharedtasks, where(is_sharedtask: false)

	scope :top_recent, order('collections.updated_at DESC').limit(10)

	def editable?(current_user)
		current_user.present? && (current_user.root? || current_user == user)
	end

	def destroyable?(current_user)
		current_user.present? && (current_user.root? || current_user == user)
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

	def annotations_ttl_dirpath
		@annotations_ttl_dirpath ||= Rails.application.config.system_path_rdf + 'collections/' + "#{name.gsub(' ', '_')}"
	end

	def create_annotations_RDF
		FileUtils.mkdir_p annotations_ttl_dirpath unless File.exists? annotations_ttl_dirpath
		FileUtils.rm_f Dir.glob("#{annotations_ttl_dirpath}/*")

		projects.indexable.each_with_index do |project, i|
			if project.rdf_needs_to_be_updated?
				delayed_job = Delayed::Job.enqueue CreateAnnotationRdfJob.new(project), queue: :general
				job = project.jobs.create({name:"Create Annotation RDF - #{project.name}", delayed_job_id:delayed_job.id})
				sleep(1) until job.finished_live?
			end
			FileUtils.ln_sf(project.annotations_ttl_filepath, annotations_ttl_dirpath)
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
