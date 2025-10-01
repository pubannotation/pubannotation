class Job < ActiveRecord::Base
  belongs_to :organization, polymorphic: true
  has_many :messages # "dependent: :destroy" is omitted. They are explicitly deleted in the destroy method
  has_many :annotation_receptions # "dependent: :destroy" is omitted. They are explicitly destroyed in the destroy method

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
    annotation_receptions.destroy_all
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
end
