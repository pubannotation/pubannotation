class Job < ActiveRecord::Base
  belongs_to :organization, polymorphic: true
  has_many :messages # "dependent: :destroy" is omitted. They are explicitly deleted in the destroy method

  scope :waiting, -> { where('begun_at IS NULL') }
  scope :running, -> { where('begun_at IS NOT NULL AND ended_at IS NULL') }
  scope :unfinished, -> { where('ended_at IS NULL') }
  scope :finished, -> { where('ended_at IS NOT NULL') }

  def start!
    update_attribute :begun_at, Time.now
  end

  def finish!
    update_attribute :ended_at, Time.now
  end

  def add_message(message)
    sourceids_str = if message[:sourceid].present? && message[:sourceid].length > 10
      sourceids = message[:sourceid]
      sourceids[0, 3].to_s + " and other #{sourceids.length - 3} ids"
    else
      message[:sourceid].to_s
    end

    if message[:sourceid].present? && message[:body].length > 500
      body = message[:body][0..500] + " ... (truncated)"
      message[:body] = body
    end

    messages << Message.create(sourcedb: message[:sourcedb], sourceid: sourceids_str, body: message[:body])
  end

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

  def suspended?
    return false unless running?
    suspend_file = Rails.root.join('tmp', "suspend_job_#{id}")
    File.exist?(suspend_file)
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

  def destroy_unless_running
    case state
    when 'Waiting'
      ApplicationJob.cancel_adapter_class.new.cancel(active_job_id, queue_name)
      destroy
    when 'Finished'
      destroy
    when 'Running'
      # do nothing
    end
  end

  def self.batch_destroy_finished(organization)
    organization.jobs.finished.each do |job|
      job.destroy
    end
  end

  def self.batch_destroy_unless_running(organization)
    organization.jobs.each do |job|
      job.destroy_unless_running
    end
  end

  def stop_if_running
    if running?
      suspend_file = Rails.root.join('tmp', "suspend_job_#{id}")
      FileUtils.touch(suspend_file)
      Rails.logger.info "[Job##{id}] Created suspension file: #{suspend_file}"
    end
  end

  def destroy
    ActiveRecord::Base.connection.exec_query("DELETE FROM messages WHERE job_id = #{id}")
    self.delete
  end

  def will_finish_at
    if begun_at.nil? || num_dones.nil? || num_dones == 0
      nil
    else
      begun_at + (Time.now - begun_at) * num_items / num_dones
    end
  end

  # This method is designed to handle the situation where Sidekiq processes are stopped
  # while jobs are still marked as "running" in the Jobs table.
  # When Sidekiq is not running, this method forcibly terminates jobs that are still in progress
  # to ensure the Jobs table reflects the correct state of the system.
  def self.reap_zombies
    return if Sidekiq::ProcessSet.new.size.positive?

    running.each do
      it.add_message sourcedb: '*',
                     sourceid: '*',
                     body: "The job was terminated because Sidekiq was stopped."
      it.finish!
    end
  end

  # Detect and clean up crashed parent jobs (jobs that stopped updating but are still marked as running)
  # This handles cases where the Sidekiq worker crashes (OOM, segfault, SIGKILL, etc)
  def self.detect_and_cleanup_crashed_jobs(timeout = 15.minutes)
    # Find jobs that are marked as running but haven't updated in a long time
    stale_jobs = running.where('updated_at < ?', timeout.ago)

    # Load the jobs into memory so the count doesn't change after we update them
    stale_jobs_array = stale_jobs.to_a

    stale_jobs_array.each do |job|
      Rails.logger.warn "[Job##{job.id}] Detected crashed parent job (no updates for #{timeout.inspect})"

      # Mark any orphaned child job tracking records as crashed/failed
      orphaned_running = BatchJobTracking.where(parent_job_id: job.id, status: 'running')
      orphaned_pending = BatchJobTracking.where(parent_job_id: job.id, status: 'pending')

      # Count before updating (update_all changes the records, so .count after would return 0)
      orphaned_running_count = orphaned_running.count
      orphaned_pending_count = orphaned_pending.count

      orphaned_running.update_all(
        status: 'crashed',
        error_message: 'Parent job crashed or was killed (worker died)',
        completed_at: Time.current
      )

      orphaned_pending.update_all(
        status: 'failed',
        error_message: 'Parent job crashed before this batch could execute',
        completed_at: Time.current
      )

      # Update final progress from tracking table
      stats = BatchJobTracking.uncached do
        BatchJobTracking.stats_for_parent(job.id)
      end
      completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

      # Add termination message
      job.add_message(
        sourcedb: '*',
        sourceid: 'system',
        body: "Job was terminated unexpectedly (parent job crashed or worker was killed). " \
              "#{orphaned_running_count} batches marked as crashed, #{orphaned_pending_count} batches marked as failed."
      )

      # Update progress and mark as finished
      job.update!(
        num_dones: completed_items,
        ended_at: job.updated_at # Use last update time as crash time
      )

      Rails.logger.info "[Job##{job.id}] Cleaned up crashed job: #{completed_items}/#{job.num_items} completed"
    end

    stale_jobs_array.count
  end
end
