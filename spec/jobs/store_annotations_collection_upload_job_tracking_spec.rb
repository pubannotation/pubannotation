require 'rails_helper'

RSpec.describe 'Batch Job Tracking Integration', type: :job do
  include ActiveJob::TestHelper

  let(:project) { create(:project) }
  let(:upload_file) { fixture_file_upload('annotations_sample.jsonl', 'application/jsonl') }
  let(:options) { { 'mode' => 'replace' } }

  describe 'tracking creation and lifecycle' do
    it 'creates tracking records when enqueuing child jobs' do
      # Create a simple JSONL file with 2 annotations
      jsonl_content = [
        { sourcedb: 'PMC', sourceid: '123', text: 'Test', denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }] },
        { sourcedb: 'PMC', sourceid: '456', text: 'Test', denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }] }
      ].map(&:to_json).join("\n")

      temp_file = Tempfile.new(['test', '.jsonl'])
      temp_file.write(jsonl_content)
      temp_file.rewind

      perform_enqueued_jobs do
        StoreAnnotationsCollectionUploadJob.perform_later(project, temp_file.path, options)
      end

      # Should have created tracking records
      expect(BatchJobTracking.count).to be > 0

      # All should be completed
      expect(BatchJobTracking.finished.count).to eq(BatchJobTracking.count)

      temp_file.close
      temp_file.unlink
    end
  end

  describe 'crash detection' do
    let(:parent_job) { create(:job, num_items: 100, num_dones: 0) }

    it 'detects and marks crashed jobs' do
      # Create a stale "running" tracking (simulating a crashed job)
      stale_tracking = create(:batch_job_tracking,
                              parent_job: parent_job,
                              status: 'running',
                              item_count: 50,
                              updated_at: 15.minutes.ago)

      # Create a recent "running" tracking (still alive)
      recent_tracking = create(:batch_job_tracking,
                               parent_job: parent_job,
                               status: 'running',
                               item_count: 50,
                               updated_at: 1.minute.ago)

      # Simulate the parent job's crash detection
      crashed_count = BatchJobTracking
        .for_parent(parent_job.id)
        .possibly_crashed(10.minutes)
        .count

      expect(crashed_count).to eq(1)

      # Mark them as crashed
      BatchJobTracking
        .for_parent(parent_job.id)
        .possibly_crashed(10.minutes)
        .find_each(&:mark_crashed!)

      stale_tracking.reload
      recent_tracking.reload

      expect(stale_tracking.status).to eq('crashed')
      expect(recent_tracking.status).to eq('running')
    end
  end

  describe 'progress tracking' do
    let(:parent_job) { create(:job) }

    it 'calculates progress from tracking records' do
      create(:batch_job_tracking, :completed, parent_job: parent_job, item_count: 30)
      create(:batch_job_tracking, :completed, parent_job: parent_job, item_count: 20)
      create(:batch_job_tracking, :running, parent_job: parent_job, item_count: 25)
      create(:batch_job_tracking, :pending, parent_job: parent_job, item_count: 25)

      stats = BatchJobTracking.stats_for_parent(parent_job.id)

      total_items = stats.values.sum
      completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

      expect(total_items).to eq(100)
      expect(completed_items).to eq(50)
    end

    it 'includes failed and crashed in completed count' do
      create(:batch_job_tracking, :completed, parent_job: parent_job, item_count: 30)
      create(:batch_job_tracking, :failed, parent_job: parent_job, item_count: 10)
      create(:batch_job_tracking, :crashed, parent_job: parent_job, item_count: 10)
      create(:batch_job_tracking, :running, parent_job: parent_job, item_count: 50)

      stats = BatchJobTracking.stats_for_parent(parent_job.id)

      completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

      expect(completed_items).to eq(50)
    end
  end

  describe 'child job error handling' do
    it 'marks tracking as failed when child job raises error' do
      parent_job = create(:job)
      tracking = create(:batch_job_tracking,
                        parent_job: parent_job,
                        status: 'pending',
                        item_count: 10)

      # Simulate child job raising an error
      error = StandardError.new('Test error')
      error.set_backtrace(['line 1', 'line 2'])

      expect {
        # Simulate what happens in ProcessAnnotationsBatchJob rescue block
        tracking.reload
        tracking.mark_running!
        raise error
      }.to raise_error(StandardError)

      # In the rescue block, we would mark as failed
      tracking.mark_failed!(error)

      tracking.reload
      expect(tracking.status).to eq('failed')
      expect(tracking.error_message).to include('Test error')
      expect(tracking.error_message).to include('line 1')
    end
  end

  describe 'cleanup' do
    let(:parent_job) { create(:job) }

    it 'deletes tracking records when parent job is deleted' do
      tracking_ids = [
        create(:batch_job_tracking, parent_job: parent_job).id,
        create(:batch_job_tracking, parent_job: parent_job).id,
        create(:batch_job_tracking, parent_job: parent_job).id
      ]

      expect(BatchJobTracking.count).to eq(3)

      parent_job.destroy

      expect(BatchJobTracking.where(id: tracking_ids).count).to eq(0)
    end

    it 'can manually clean up old tracking records' do
      old_job = create(:job)
      old_tracking = create(:batch_job_tracking,
                            parent_job: old_job,
                            created_at: 8.days.ago)

      new_job = create(:job)
      new_tracking = create(:batch_job_tracking,
                            parent_job: new_job,
                            created_at: 1.day.ago)

      # Clean up records older than 7 days
      BatchJobTracking.older_than(7.days.ago).delete_all

      expect(BatchJobTracking.exists?(old_tracking.id)).to be false
      expect(BatchJobTracking.exists?(new_tracking.id)).to be true
    end
  end

  describe 'batch state management' do
    let(:parent_job) { create(:job) }

    it 'creates tracking record before enqueuing child job' do
      project = create(:project)
      options = {}
      batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(project, options, parent_job.id)

      # Add annotations to batch
      annotation = {
        sourcedb: 'PMC',
        sourceid: '123',
        text: 'Test',
        denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }]
      }

      batch_state.add_to_batch(annotation)

      # Manually flush to trigger tracking creation
      # Note: This will actually try to enqueue a job, so we need to stub it
      allow(ProcessAnnotationsBatchJob).to receive(:perform_later).and_return(
        double(job_id: 'test_job_id')
      )

      expect {
        batch_state.flush_batch
      }.to change { BatchJobTracking.count }.by(1)

      tracking = BatchJobTracking.last
      expect(tracking.parent_job_id).to eq(parent_job.id)
      expect(tracking.status).to eq('pending')
      expect(tracking.doc_identifiers).to include({ 'sourcedb' => 'PMC', 'sourceid' => '123' })
    end
  end

  describe 'error message formatting' do
    it 'includes error class, message, and backtrace' do
      tracking = create(:batch_job_tracking)

      error = ArgumentError.new('Invalid argument provided')
      error.set_backtrace([
        '/path/to/file.rb:123:in `method_name`',
        '/path/to/other.rb:456:in `other_method`'
      ])

      tracking.mark_failed!(error)

      expect(tracking.error_message).to include('ArgumentError')
      expect(tracking.error_message).to include('Invalid argument provided')
      expect(tracking.error_message).to include('/path/to/file.rb:123')
    end
  end
end
