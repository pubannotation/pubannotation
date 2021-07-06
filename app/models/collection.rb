require 'fileutils'

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

	def spans_trig_filepath
		annotations_rdf_dirpath + "/#{name.gsub(' ', '_')}-spans.trig"
	end

	def create_spans_RDF
		pprojects = self.primary_projects
		unless pprojects.empty?
			pproject = pprojects.first

			# pproject.create_spans_RDF

			# CreateSpansRdfJob.perform_now(pproject)

			active_job = CreateSpansRdfJob.perform_later(pproject, self)
			job = Job.find_by(active_job_id: active_job.job_id)
			sleep(1) until job.finished_live?

			FileUtils.ln_sf(pproject.spans_trig_filepath, annotations_rdf_dirpath)
		end
	end

	def last_indexed_at
		begin
			File.mtime(annotations_rdf_dirpath)
		rescue
			nil
		end
	end

	def last_indexed_at_live(endpoint = nil)
		nil
	end

end
