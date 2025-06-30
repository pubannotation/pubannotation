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
    if message[:sourceid].present? && message[:sourceid].length > 250
      sourceids = message[:sourceid].split(", ")
      message[:sourceid] = sourceids[0, 3].to_s + " and other #{sourceids.length - 3} ids"
    end

    if message[:sourceid].present? && message[:body].length > 250
      body = message[:body][0..235] + " ... (truncated)"
      message[:body] = body
    end

    messages << Message.create(message)
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
    running? && suspend_flag == true
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
      update(suspend_flag: true)
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

  def self.update_dead_jobs_status(jobs)
    running_jobs = jobs.running

    return if running_jobs.empty? || Sidekiq::ProcessSet.new.size.positive?

    running_jobs.each(&:finish!)
  end
end
