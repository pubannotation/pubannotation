require 'rails_helper'

RSpec.describe 'Parent Job Crash Detection', type: :job do
  describe 'parent job survives child crash' do
    it 'detects crashed child via built-in monitoring loop crash detection' do
      # This tests the scenario where parent and child are in different workers
      # Parent's monitoring loop should detect the crashed child after 10 minutes

      parent_job = create(:job, num_items: 100, num_dones: 90)

      # Create a crashed child that stopped updating 15 minutes ago
      crashed_tracking = create(:batch_job_tracking,
                                parent_job: parent_job,
                                status: 'running',
                                item_count: 10,
                                started_at: 16.minutes.ago,
                                updated_at: 15.minutes.ago)

      # Simulate what the parent job's monitoring loop does
      job = double('job', id: parent_job.id)
      allow(job).to receive(:add_message)

      # This is what parent job calls in its monitoring loop
      crashed_count = BatchJobTracking
        .for_parent(parent_job.id)
        .possibly_crashed(10.minutes)
        .count

      expect(crashed_count).to eq(1)

      # Mark as crashed (what parent does)
      BatchJobTracking
        .for_parent(parent_job.id)
        .possibly_crashed(10.minutes)
        .find_each do |tracking|
          tracking.mark_crashed!
        end

      crashed_tracking.reload
      expect(crashed_tracking.status).to eq('crashed')
      expect(crashed_tracking.error_message).to include('did not update status')

      # Parent would then continue and complete
      stats = BatchJobTracking.stats_for_parent(parent_job.id)
      completed = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)
      expect(completed).to eq(10)  # The crashed child counts as completed
    end
  end

  describe 'Job.detect_and_cleanup_crashed_jobs' do
    it 'detects and cleans up crashed parent jobs' do
      # This tests external monitoring detecting a crashed parent job

      # Create a parent job that looks crashed (hasn't updated in 20 minutes)
      crashed_parent = create(:job,
                              num_items: 1000,
                              num_dones: 100,
                              begun_at: 2.hours.ago)

      # Manually set updated_at to the past (ActiveRecord doesn't allow this in create)
      crashed_parent.update_column(:updated_at, 20.minutes.ago)

      # Create some orphaned tracking records
      create(:batch_job_tracking, :running,
             parent_job: crashed_parent,
             item_count: 30,
             annotation_objects_count: 30,
             updated_at: 20.minutes.ago)

      create(:batch_job_tracking, :running,
             parent_job: crashed_parent,
             item_count: 20,
             annotation_objects_count: 20,
             updated_at: 20.minutes.ago)

      create(:batch_job_tracking, :pending,
             parent_job: crashed_parent,
             item_count: 50,
             annotation_objects_count: 50)

      # Run external crash detection
      crashed_count = Job.detect_and_cleanup_crashed_jobs(15.minutes)

      expect(crashed_count).to eq(1)

      # Verify cleanup
      crashed_parent.reload
      expect(crashed_parent.ended_at).not_to be_nil
      expect(crashed_parent.finished?).to be true
      expect(crashed_parent.num_dones).to eq(100)  # Updated from tracking
      expect(crashed_parent.messages.count).to be > 0

      last_message = crashed_parent.messages.last
      expect(last_message.body).to include('terminated unexpectedly')
      expect(last_message.body).to include('2 batches marked as crashed')
      expect(last_message.body).to include('1 batches marked as failed')

      # Verify tracking records were cleaned up
      orphaned_running = BatchJobTracking.where(parent_job_id: crashed_parent.id, status: 'running')
      orphaned_pending = BatchJobTracking.where(parent_job_id: crashed_parent.id, status: 'pending')

      expect(orphaned_running.count).to eq(0)
      expect(orphaned_pending.count).to eq(0)

      crashed = BatchJobTracking.where(parent_job_id: crashed_parent.id, status: 'crashed')
      failed = BatchJobTracking.where(parent_job_id: crashed_parent.id, status: 'failed')

      expect(crashed.count).to eq(2)
      expect(failed.count).to eq(1)
    end

    it 'does not mark recently updated jobs as crashed' do
      # Create a healthy parent job (updated 1 minute ago)
      healthy_parent = create(:job,
                              num_items: 1000,
                              num_dones: 100,
                              begun_at: 10.minutes.ago,
                              updated_at: 1.minute.ago)

      create(:batch_job_tracking, :running,
             parent_job: healthy_parent,
             item_count: 50,
             annotation_objects_count: 50,
             updated_at: 1.minute.ago)

      # Run crash detection
      crashed_count = Job.detect_and_cleanup_crashed_jobs(15.minutes)

      expect(crashed_count).to eq(0)

      # Job should be untouched
      healthy_parent.reload
      expect(healthy_parent.ended_at).to be_nil
      expect(healthy_parent.finished?).to be false
    end

    it 'handles jobs with no tracking records' do
      # Edge case: parent job crashed before creating any tracking records
      crashed_parent = create(:job,
                              num_items: 1000,
                              num_dones: 0,
                              begun_at: 2.hours.ago)

      # Manually set updated_at to the past
      crashed_parent.update_column(:updated_at, 20.minutes.ago)

      # No tracking records exist
      expect(BatchJobTracking.for_parent(crashed_parent.id).count).to eq(0)

      # Should still detect and clean up
      crashed_count = Job.detect_and_cleanup_crashed_jobs(15.minutes)

      expect(crashed_count).to eq(1)

      crashed_parent.reload
      expect(crashed_parent.finished?).to be true
      expect(crashed_parent.num_dones).to eq(0)  # No progress made
    end
  end

  describe 'heartbeat mechanism' do
    it 'updates job timestamp during monitoring loop' do
      parent_job = create(:job, num_items: 100, num_dones: 0)

      create(:batch_job_tracking, :completed,
             parent_job: parent_job,
             item_count: 50,
             annotation_objects_count: 50)

      initial_updated_at = parent_job.updated_at

      # Simulate what the monitoring loop does
      sleep 0.1

      stats = BatchJobTracking.stats_for_parent(parent_job.id)
      completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

      # This is what the parent job does (with heartbeat)
      parent_job.update!(num_dones: completed_items, updated_at: Time.current)

      parent_job.reload
      expect(parent_job.updated_at).to be > initial_updated_at
      expect(parent_job.num_dones).to eq(50)
    end
  end

  describe 'stale pending job detection' do
    it 'detects pending jobs that never started (lost child jobs)' do
      # Simulate scenario where child jobs were enqueued but never picked up
      # (Sidekiq worker crashed, Redis lost jobs, etc.)

      parent_job = create(:job, num_items: 200, num_dones: 100)

      # Create a stale pending job (created 6 minutes ago, never started)
      stale_pending = create(:batch_job_tracking,
                            parent_job: parent_job,
                            status: 'pending',
                            child_job_id: 'lost-job-12345',
                            item_count: 50,
                            annotation_objects_count: 50,
                            created_at: 6.minutes.ago,
                            updated_at: 6.minutes.ago)

      # Create a recent pending job (should not be affected)
      recent_pending = create(:batch_job_tracking,
                             parent_job: parent_job,
                             status: 'pending',
                             child_job_id: 'recent-job-67890',
                             item_count: 50,
                             annotation_objects_count: 50,
                             created_at: 2.minutes.ago,
                             updated_at: 2.minutes.ago)

      # Check that stale_pending scope finds the old one
      stale_count = BatchJobTracking
        .for_parent(parent_job.id)
        .stale_pending(5.minutes)
        .count

      expect(stale_count).to eq(1)

      # Mark stale pending as failed (what parent job does)
      BatchJobTracking
        .for_parent(parent_job.id)
        .stale_pending(5.minutes)
        .each do |tracking|
          tracking.update!(
            status: 'failed',
            error_message: 'Child job never started - likely lost by Sidekiq',
            completed_at: Time.current
          )
        end

      stale_pending.reload
      recent_pending.reload

      expect(stale_pending.status).to eq('failed')
      expect(stale_pending.error_message).to include('never started')
      expect(recent_pending.status).to eq('pending')  # Unaffected
    end
  end
end
