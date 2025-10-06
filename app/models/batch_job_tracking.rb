class BatchJobTracking < ApplicationRecord
  belongs_to :parent_job, class_name: 'Job', foreign_key: :parent_job_id

  # Status values
  STATUSES = %w[pending running completed failed crashed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :parent_job_id, presence: true
  validates :item_count, numericality: { greater_than: 0 }

  # Scopes for efficient querying
  scope :for_parent, ->(job_id) { where(parent_job_id: job_id) }
  scope :pending, -> { where(status: 'pending') }
  scope :running, -> { where(status: 'running') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :crashed, -> { where(status: 'crashed') }
  scope :finished, -> { where(status: %w[completed failed crashed]) }

  # Jobs that have been running too long (likely crashed)
  scope :possibly_crashed, ->(timeout = 10.minutes) {
    where(status: 'running')
      .where('updated_at < ?', timeout.ago)
  }

  # Jobs stuck in pending status that never started (child job lost/never executed)
  scope :stale_pending, ->(timeout = 5.minutes) {
    where(status: 'pending')
      .where('created_at < ?', timeout.ago)
  }

  # Jobs created before a certain time (for cleanup)
  scope :older_than, ->(time) { where('created_at < ?', time) }

  # Get aggregated stats for a parent job
  def self.stats_for_parent(parent_job_id)
    # Return hash with status => annotation_objects_count (for progress tracking)
    for_parent(parent_job_id)
      .group(:status)
      .pluck(Arel.sql('status, SUM(annotation_objects_count)::integer'))
      .to_h
  end

  # Mark this tracking record as running
  def mark_running!
    update!(status: 'running', started_at: Time.current)
  end

  # Mark this tracking record as completed
  def mark_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  # Mark this tracking record as failed
  def mark_failed!(error)
    update!(
      status: 'failed',
      error_message: "#{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}",
      completed_at: Time.current
    )
  end

  # Mark this tracking record as crashed
  def mark_crashed!
    update!(
      status: 'crashed',
      error_message: 'Job did not update status within expected timeframe (likely crashed or killed)',
      completed_at: Time.current
    )
  end

  # Duration of job execution
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  # Human-readable status
  def status_label
    case status
    when 'pending' then 'Waiting to start'
    when 'running' then 'In progress'
    when 'completed' then 'Completed successfully'
    when 'failed' then 'Failed with error'
    when 'crashed' then 'Crashed or killed'
    else status.titleize
    end
  end

  # Get short doc summary for display
  def doc_summary(limit = 3)
    return '(no docs)' if doc_identifiers.blank?

    sample = doc_identifiers.take(limit)
    summary = sample.map { |d| "#{d['sourcedb']}:#{d['sourceid']}" }.join(', ')
    summary += "... (#{doc_identifiers.size - limit} more)" if doc_identifiers.size > limit
    summary
  end
end
