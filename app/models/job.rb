class Job < ActiveRecord::Base
	belongs_to :organization, polymorphic: true
	belongs_to :delayed_job, optional: true
	has_many :messages, :dependent => :destroy

	scope :waiting, -> {where('begun_at IS NULL')}
	scope :running, -> {where('begun_at IS NOT NULL AND ended_at IS NULL')}
	scope :unfinished, -> {where('ended_at IS NULL')}
	scope :finished, -> {where('ended_at IS NOT NULL')}


	def waiting?
		begun_at.nil?
	end

	def running?
		!begun_at.nil? && ended_at.nil?
	end

	def finished?
		!ended_at.nil?
	end

	def finished_live?
		!ActiveRecord::Base.connection.select_value("select ended_at from jobs where id = #{id}").nil?
	end

	def unfinished?
		ended_at.nil?
	end

	def state
		if begun_at.nil?
			'Waiting'
		elsif ended_at.nil?
			'Running'
		else
			'Finished'
		end
	end

	def destroy_if_not_running
		case state
		when 'Waiting'
			ApplicationJob.cancel_adapter_class.new.cancel(active_job_id, queue_name)
			Message.where(job_id: id).delete_all
			destroy
		when 'Finished'
			Message.where(job_id: id).delete_all
			destroy
		when 'Running'
			# do nothing
		end
	end

	def stop_if_running
		if running?
			dj = begin
				Delayed::Job.find(self.delayed_job_id)
			rescue
				nil
			end
			unless dj.nil?
				dj.locked_by.match(/delayed_job.(\d+)/)
				worker_id = $1.to_i
				`script/delayed_job -i #{worker_id} restart`
				update_attribute(:ended_at, Time.now)
			end
		end
	end
end
