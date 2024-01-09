  class UpdateParagraphReferencesJob < ApplicationJob
  queue_as :low_priority

  before_perform :before_perform
  after_perform :after_perform
  rescue_from(StandardError) { |exception| rescue_from exception }

  # We assume a maximum of 14 million docs in a single data source;
  # we will create about 100 jobs, divided into 100,000 jobs every 100,000 docs.
  def self.create_jobs(source_db, is_immediate = false, chunk_size = 100_000)
    docs = Doc.where(sourcedb: source_db)
    return if docs.empty?

    # A series of update processes could take several days.
    # Avoid queuing multiple processes.
    raise 'already queued' if queued_jobs.exists?

    # Job must has a organization, so we use admin project as a dummy.
    project = Project.find_by id: Pubann::Admin::ProjectId
    project.jobs.create! name: job_name,
                         num_items: docs.size,
                         num_dones: 0

    docs.each_slice(chunk_size) do |docs|
      is_immediate ? perform_now(docs) : self.perform_later(docs)
    end

    true
  end

  # This method is for debug.
  def self.destroy_jobs
    jobs.destroy_all
  end

  def perform(docs)
    @sourcedb = docs.first.sourcedb
    @docs = docs

    docs.each do |doc|
      @sourceid = doc.sourceid
      doc.update_all_references_in_paragraphs
    end
  end

  def self.job_name = self.class.name
  def self.jobs = Job.where(name: job_name)
  def jobs = self.class.jobs
  def self.queued_jobs = jobs.where(ended_at: nil)
  def queued_jobs = self.class.queued_jobs

  private

  def before_perform
    # It is assumed that only one job is queued at a time.
    @job = queued_jobs.first
    @job.start! if @job.waiting?
  end

  def after_perform
    update_num_dones
    @job.finish! if @job.num_dones == @job.num_items
  end

  def rescue_from(exception)
    @job.add_message sourcedb: @sourcedb,
                     sourceid: @sourceid,
                     divid: nil,
                     body: exception.message[0..250]
    after_perform
    raise exception
  end

  def update_num_dones
    @job.transaction do
      @job.reload
      @job.update_attribute(:num_dones, @job.num_dones + @docs.size)
    end
  end
end
