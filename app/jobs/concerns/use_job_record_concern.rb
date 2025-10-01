# frozen_string_literal: true

module UseJobRecordConcern
  extend ActiveSupport::Concern

  included do
    rescue_from(StandardError) { |exception| handle_standard_error(exception) }
    before_enqueue :before_enqueue
    before_perform { |active_job| before_perform active_job }
    after_perform :after_perform
  end

  def handle_standard_error(exception)
    # If the job instance is not set, this job is called by perform_now.
    raise exception unless @job

    @pool.kill if @pool.present?

    body = "class: #{exception.class.name}, message: #{exception.message}"
    if Rails.env.development? && !exception.is_a?(Exceptions::JobSuspendError)
      body << ", backtrace: #{exception.backtrace ? exception.backtrace[0..2] : 'no backtrace'}"
    end

    @job.add_message sourcedb: '*',
                     sourceid: '*',
                     divid: nil,
                     body: body
    @job.finish!
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

    # @job is created when the job is called by perform_later.
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
      job_name = respond_to?(:job_name) ? job_name : self.class.name
      raise Exceptions::JobSuspendError, "#{job_name} suspended by user request - processing can be resumed later."
    end
  end

  def suspended?
    @job&.suspended?
  end

  def suspend_job!
    return unless @job
    suspend_file = Rails.root.join('tmp', "suspend_job_#{@job.id}")
    FileUtils.touch(suspend_file)
    Rails.logger.info "[#{self.class.name}] Created suspension file: #{suspend_file}"
  end

  def prepare_progress_record(scheduled_num)
    @job&.update_attribute(:num_items, scheduled_num)
    @job&.update_attribute(:num_dones, 0)
  end

  def increment_progress(count = 1)
    @job&.increment!(:num_dones, count)
  end
end
