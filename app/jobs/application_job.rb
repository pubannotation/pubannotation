class ApplicationJob < ActiveJob::Base
  def create_job_record(organization_jobs, job_name)
    delayed_job = Delayed::Job.find(self.provider_job_id)
    organization_jobs.create({ name: job_name, active_job_id: self.job_id, delayed_job_id: delayed_job.id, queue_name: self.queue_name })
  end

  rescue_from(StandardError) do |exception|
    if @job
      @job.messages << Message.create({sourcedb: '*', sourceid: '*', divid: nil, body: exception.message})
      set_ended_at
    end
    raise exception
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

  def set_job(active_job)
    @job = Job.find_by(active_job_id: active_job.job_id)
  end

  def set_begun_at
    @job.update_attribute(:begun_at, Time.now)
  end

  def set_ended_at
    @job.update_attribute(:ended_at, Time.now)
  end
end
