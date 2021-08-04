class ApplicationJob < ActiveJob::Base
  rescue_from(StandardError) do |exception|
    if @job
      @job.messages << Message.create({sourcedb: '*', sourceid: '*', divid: nil, body: exception.message})
      set_ended_at
    else
      # Exception handling when Job is executed synchronously with perform_now
      raise exception
    end
  end

  before_enqueue do
    # When creating a new job,
    # be sure to pass the organization to which the Job record belongs to the first argument of the perform method.
    create_job_record(organization_jobs, self.job_name)
  end

  before_perform do |active_job|
    if set_job(active_job)
      set_begun_at
    end
  end

  after_perform do
    if @job
      set_ended_at
    end
  end

  private

  def organization_jobs
    self.arguments.first.jobs
  end

  def resource_name
    self.arguments.first.name
  end

  def create_job_record(organization_jobs, job_name)
    organization_jobs.create({ name: job_name, active_job_id: self.job_id, queue_name: self.queue_name })
  end

  def set_job(active_job)
    @job = Job.find_by(active_job_id: active_job.job_id)
  end

  def set_begun_at
    @job.update_attribute(:begun_at, Time.now)
  end

  def set_ended_at
    @job.update_attribute(:ended_at, Time.now)
  end

  def check_suspend_flag
    if suspended?
      raise Exceptions::JobSuspendError
    end
  end

  def suspended?
    Job.find(@job.id)&.suspended?
  end

  def prepare_progress_record(scheduled_num)
    @job.update_attribute(:num_items, scheduled_num)
    @job.update_attribute(:num_dones, 0)
  end
end
