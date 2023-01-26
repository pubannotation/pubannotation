class ApplicationJob < ActiveJob::Base
  rescue_from(StandardError) { |exception| handle_standard_error(exception) }
  before_enqueue :before_enqueue
  before_perform { |active_job| before_perform active_job }
  after_perform :after_perform

  private

  def handle_standard_error(exception)
    if @job
      body = exception.message[0..250]

      if Rails.env.development? && !exception.is_a?(Exceptions::JobSuspendError)
        body << "\n#{exception.backtrace_locations ? exception.backtrace_locations[0..2] : 'no backtrace;'}"
      end

      @job.add_message sourcedb: '*',
                       sourceid: '*',
                       divid: nil,
                       body: body
      @job.finish!
    else
      # Exception handling when Job is executed synchronously with perform_now
      raise exception
    end
  end

  def before_enqueue
    # When creating a new job,
    # be sure to pass the organization to which the Job record belongs to the first argument of the perform method.
    self.arguments.first.jobs.create name: self.job_name,
                                     active_job_id: self.job_id,
                                     queue_name: self.queue_name
  end

  def before_perform(active_job)
    @job = Job.find_by(active_job_id: active_job.job_id)
    @job&.start!
  end

  def after_perform
    @job&.finish!
  end

  def resource_name
    self.arguments.first.name
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
