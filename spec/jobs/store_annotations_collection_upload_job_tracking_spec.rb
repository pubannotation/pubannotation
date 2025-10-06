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

    describe 'consecutive duplicate detection' do
      let(:project) { create(:project) }
      let(:annotation1) do
        {
          sourcedb: 'PMC',
          sourceid: '123',
          text: 'Test',
          denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }]
        }
      end

      let(:annotation2) do
        {
          sourcedb: 'PMC',
          sourceid: '456',
          text: 'Another',
          denotations: [{ span: { begin: 0, end: 7 }, obj: 'Test' }]
        }
      end

      it 'raises error when consecutive duplicate documents in replace mode' do
        batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(
          project,
          { mode: 'replace' },
          parent_job.id
        )

        # Add first annotation
        batch_state.add_to_batch(annotation1)

        # Try to add duplicate (same sourcedb:sourceid)
        expect {
          batch_state.add_to_batch(annotation1.dup)
        }.to raise_error(ArgumentError)

        # Verify message was added with proper fields
        parent_job.reload
        message = parent_job.messages.last
        expect(message.sourcedb).to eq('PMC')
        expect(message.sourceid).to eq('123')
        expect(message.body).to include('document appears multiple times')
        expect(message.body).to include("use 'add' mode")
        expect(message.body).not_to include('ArgumentError')
      end

      it 'allows consecutive duplicate documents in add mode' do
        batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(
          project,
          { mode: 'add' },
          parent_job.id
        )

        # Add first annotation
        batch_state.add_to_batch(annotation1)

        # Add duplicate - should not raise error in add mode
        expect {
          batch_state.add_to_batch(annotation1.dup)
        }.not_to raise_error
      end

      it 'allows same document when not consecutive' do
        batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(
          project,
          { mode: 'replace' },
          parent_job.id
        )

        # Add first annotation
        batch_state.add_to_batch(annotation1)

        # Add different document
        batch_state.add_to_batch(annotation2)

        # Add first document again - should not raise error since not consecutive
        expect {
          batch_state.add_to_batch(annotation1.dup)
        }.not_to raise_error
      end

      it 'message is user-friendly without technical details' do
        batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(
          project,
          { mode: 'replace' },
          parent_job.id
        )

        batch_state.add_to_batch(annotation1)

        expect {
          batch_state.add_to_batch(annotation1.dup)
        }.to raise_error(ArgumentError)

        # Verify message is user-friendly
        parent_job.reload
        message = parent_job.messages.last
        expect(message.body).not_to include('ArgumentError')
        expect(message.body).not_to include('backtrace')
        expect(message.body).not_to include('PMC:123')  # Should be in fields, not body
        expect(message.body).to match(/use 'add' mode/i)
      end
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

  describe 'progress counter updates' do
    describe 'during queue throttling' do
      it 'updates num_dones but preserves num_items' do
        parent_job = create(:job, num_items: 100, num_dones: 0)
        project = create(:project)
        options = {}
        batch_state = StoreAnnotationsCollectionUploadJob::BatchState.new(project, options, parent_job.id)

        # Create some completed tracking records
        create(:batch_job_tracking, :completed, parent_job: parent_job, annotation_objects_count: 30)
        create(:batch_job_tracking, :completed, parent_job: parent_job, annotation_objects_count: 20)

        # Stub Sidekiq queue to be full initially
        full_queue = double('Queue', size: 150)  # Over MAX_QUEUE_SIZE (100)
        empty_queue = double('Queue', size: 10)  # Under MAX_QUEUE_SIZE

        allow(Sidekiq::Queue).to receive(:new).with('general').and_return(full_queue, full_queue, empty_queue)

        # Stub job enqueue
        allow(ProcessAnnotationsBatchJob).to receive(:perform_later).and_return(
          double(job_id: 'test_job_id')
        )

        # Add and flush a batch in a thread to avoid blocking
        thread = Thread.new do
          batch_state.add_to_batch({
            sourcedb: 'PMC',
            sourceid: '123',
            text: 'Test',
            denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }]
          })
          batch_state.flush_batch
        end

        # Wait a bit for throttling to trigger
        sleep(0.6)

        # Verify progress was updated during throttling wait
        parent_job.reload
        expect(parent_job.num_dones).to eq(50)  # 30 + 20 from completed tracking

        # Wait for thread to complete
        thread.join

        # Verify num_items stayed the same
        parent_job.reload
        expect(parent_job.num_items).to eq(100)  # Should NOT change
      end
    end

    describe 'on job suspension' do
      it 'updates progress and project stats before re-raising error' do
        # Create a simple JSONL file with multiple lines to trigger multiple check_suspend_flag calls
        jsonl_content = (1..10).map do |i|
          { sourcedb: 'PMC', sourceid: "#{i}", text: 'Test', denotations: [{ span: { begin: 0, end: 4 }, obj: 'Test' }] }.to_json
        end.join("\n")

        temp_file = Tempfile.new(['test', '.jsonl'])
        temp_file.write(jsonl_content)
        temp_file.rewind

        # Capture the job instance so we can get its job record
        job_instance = nil
        allow(StoreAnnotationsCollectionUploadJob).to receive(:new).and_wrap_original do |original, *args|
          job_instance = original.call(*args)
          job_instance
        end

        # Mock the suspend check to raise error on first call
        allow_any_instance_of(StoreAnnotationsCollectionUploadJob).to receive(:check_suspend_flag) do
          # Create some completed tracking records before suspension
          parent_job = Job.find_by(active_job_id: job_instance.job_id)
          create(:batch_job_tracking, :completed, parent_job: parent_job, item_count: 40) if parent_job
          raise Exceptions::JobSuspendError, 'Job suspended by user'
        end

        # Stub child job processing to avoid sequencer issues
        allow(ProcessAnnotationsBatchJob).to receive(:perform_later).and_return(
          double(job_id: 'test_job_id')
        )

        # Run the job (JobSuspendError will be caught and handled internally)
        perform_enqueued_jobs do
          StoreAnnotationsCollectionUploadJob.perform_later(project, temp_file.path, options)
        end

        # Get the job record that was created
        parent_job = Job.find_by(active_job_id: job_instance.job_id)

        # Verify the job has a suspension message
        expect(parent_job.messages.map(&:body)).to include(
          a_string_matching(/JobSuspendError/)
        )

        # Verify num_dones was updated but num_items stayed the same
        expect(parent_job.num_dones).to eq(40)  # Updated from tracking
        expect(parent_job.num_items).to eq(10)  # Should stay at the initial value (10 lines in jsonl)

        temp_file.close
        temp_file.unlink
      end
    end
  end
end
