require 'sidekiq/api'

# References are updated on a source DB basis.
# The source DB may contain 10 million documents.
# An ActiveJob job is created for every 100,000 documents.
# The progress of the ActiveJob jobs is stored in the jobs table;
# The ActiveJob job uses a dedicated queue,
# and the entire queue is destroyed when the update process is stopped.
class UpdateParagraphReferencesJob < ApplicationJob
  before_perform { |job| before_perform job }
  after_perform :after_perform
  rescue_from(StandardError) { |exception| rescue_from exception }

  PARAGRAPH = 'update_paragraph_references'

  class << self
    # We assume a maximum of 14 million docs in a single data source;
    # we will create about 100 jobs, divided into 100,000 jobs every 100,000 docs.
    def create_jobs(source_db, target_name, chunk_size = 100_000, is_immediate = false)
      docs = Doc.where(sourcedb: source_db)
      return if docs.empty?

      # A series of update processes could take several days.
      # Avoid queuing multiple processes.
      raise 'already queued' if job_for target_name

      create_job_record target_name, docs
      docs.each_slice(chunk_size) do |docs|
        # Set queue to target to separate the queue each target.
        is_immediate ? perform_now(docs, target_name) : set(queue: target_name).perform_later(docs, target_name)
      end

      true
    end

    def job_for(target_name)
      Job.where(name: target_name).where(ended_at: nil).first
    end

    # This method is for debug.
    def destroy_jobs(target_name)
      Sidekiq::Queue.new(target_name).clear
      Job.where(name: target_name).destroy_all
    end

    private

    def create_job_record(target_name, docs)
      # Job must has a organization, so we use admin project as a dummy.
      project = Project.find_by id: Pubann::Admin::ProjectId
      project.jobs.create! name: target_name,
                           num_items: docs.size,
                           num_dones: 0
    end
  end

  def perform(docs, target_name)
    @sourcedb = docs.first.sourcedb
    @docs = docs

    docs.each do |doc|
      @sourceid = doc.sourceid
      case target_name
      in PARAGRAPH
        doc.update_all_references_in_paragraphs
      end
    end
  end

  private

  def before_perform(job)
    # It is assumed that only one job is queued at a time.
    target_name = job.arguments.second
    @job = self.class.job_for target_name
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
