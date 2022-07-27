class ApplicationJob < ActiveJob::Base
  rescue_from(StandardError) { |exception| handle_standard_error(exception) }
  before_enqueue :before_enqueue
  before_perform { |active_job_id| before_perform active_job_id }
  after_perform :after_perform

  private

  def handle_standard_error(exception)
    if @job
      @job.messages << Message.create({sourcedb: '*', sourceid: '*', divid: nil, body: exception.message})
      set_ended_at
    else
      # Exception handling when Job is executed synchronously with perform_now
      raise exception
    end
  end

  def before_enqueue
    # When creating a new job,
    # be sure to pass the organization to which the Job record belongs to the first argument of the perform method.
    create_job_record(organization_jobs, self.job_name)
  end

  def before_perform(active_job_id)
    if set_job active_job_id
      set_begun_at
    end
  end

  def after_perform
    set_ended_at
  end

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
    if @job
      @job.update_attribute(:ended_at, Time.now)
    end
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
