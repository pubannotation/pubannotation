require 'rails_helper'

RSpec.describe BatchJobTracking, type: :model do
  let(:parent_job) { create(:job) }
  let(:tracking) do
    create(:batch_job_tracking,
           parent_job: parent_job,
           doc_identifiers: [
             { 'sourcedb' => 'PMC', 'sourceid' => '123' },
             { 'sourcedb' => 'PMC', 'sourceid' => '456' }
           ],
           item_count: 10)
  end

  describe 'associations' do
    it 'belongs to parent_job' do
      expect(tracking.parent_job).to eq(parent_job)
    end
  end

  describe 'validations' do
    it 'validates status is in STATUSES list' do
      valid_tracking = build(:batch_job_tracking, parent_job: parent_job, status: 'completed')
      expect(valid_tracking).to be_valid

      invalid_tracking = build(:batch_job_tracking, parent_job: parent_job, status: 'invalid_status')
      expect(invalid_tracking).not_to be_valid
    end

    it 'validates presence of parent_job_id' do
      tracking = build(:batch_job_tracking, parent_job_id: nil)
      expect(tracking).not_to be_valid
    end

    it 'validates item_count is greater than 0' do
      tracking = build(:batch_job_tracking, item_count: 0)
      expect(tracking).not_to be_valid
      expect(tracking.errors[:item_count]).to include('must be greater than 0')
    end
  end

  describe 'scopes' do
    let!(:pending_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'pending') }
    let!(:running_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'running') }
    let!(:completed_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'completed') }
    let!(:failed_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'failed') }
    let!(:crashed_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'crashed') }

    describe '.for_parent' do
      it 'returns trackings for a specific parent job' do
        other_job = create(:job)
        other_tracking = create(:batch_job_tracking, parent_job: other_job)

        expect(BatchJobTracking.for_parent(parent_job.id)).to include(pending_tracking, running_tracking)
        expect(BatchJobTracking.for_parent(parent_job.id)).not_to include(other_tracking)
      end
    end

    describe '.pending' do
      it 'returns only pending trackings' do
        expect(BatchJobTracking.pending).to eq([pending_tracking])
      end
    end

    describe '.running' do
      it 'returns only running trackings' do
        expect(BatchJobTracking.running).to eq([running_tracking])
      end
    end

    describe '.finished' do
      it 'returns completed, failed, and crashed trackings' do
        expect(BatchJobTracking.finished).to match_array([completed_tracking, failed_tracking, crashed_tracking])
      end
    end

    describe '.possibly_crashed' do
      let!(:stale_running) do
        create(:batch_job_tracking,
               parent_job: parent_job,
               status: 'running',
               updated_at: 15.minutes.ago)
      end
      let!(:recent_running) do
        create(:batch_job_tracking,
               parent_job: parent_job,
               status: 'running',
               updated_at: 5.minutes.ago)
      end

      it 'returns running jobs that have not been updated recently' do
        expect(BatchJobTracking.possibly_crashed(10.minutes)).to eq([stale_running])
      end
    end

    describe '.older_than' do
      let!(:old_tracking) do
        create(:batch_job_tracking,
               parent_job: parent_job,
               created_at: 8.days.ago)
      end
      let!(:new_tracking) do
        create(:batch_job_tracking,
               parent_job: parent_job,
               created_at: 1.day.ago)
      end

      it 'returns trackings created before the specified time' do
        expect(BatchJobTracking.older_than(7.days.ago)).to eq([old_tracking])
      end
    end
  end

  describe '.stats_for_parent' do
    let!(:pending_tracking_1) { create(:batch_job_tracking, parent_job: parent_job, status: 'pending', item_count: 10) }
    let!(:pending_tracking_2) { create(:batch_job_tracking, parent_job: parent_job, status: 'pending', item_count: 15) }
    let!(:running_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'running', item_count: 20) }
    let!(:completed_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'completed', item_count: 30) }
    let!(:failed_tracking) { create(:batch_job_tracking, parent_job: parent_job, status: 'failed', item_count: 5) }

    it 'returns aggregated stats by status' do
      stats = BatchJobTracking.stats_for_parent(parent_job.id)

      expect(stats).to eq({
        'pending' => 25,   # 10 + 15
        'running' => 20,
        'completed' => 30,
        'failed' => 5
      })
    end
  end

  describe '#mark_running!' do
    it 'updates status to running and sets started_at' do
      freeze_time do
        tracking.mark_running!

        expect(tracking.status).to eq('running')
        expect(tracking.started_at).to eq(Time.current)
      end
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed and sets completed_at' do
      freeze_time do
        tracking.mark_completed!

        expect(tracking.status).to eq('completed')
        expect(tracking.completed_at).to eq(Time.current)
      end
    end
  end

  describe '#mark_failed!' do
    it 'updates status to failed and sets error message and completed_at' do
      error = StandardError.new('Something went wrong')
      error.set_backtrace(['line 1', 'line 2', 'line 3'])

      freeze_time do
        tracking.mark_failed!(error)

        expect(tracking.status).to eq('failed')
        expect(tracking.error_message).to include('StandardError: Something went wrong')
        expect(tracking.error_message).to include('line 1')
        expect(tracking.completed_at).to eq(Time.current)
      end
    end
  end

  describe '#mark_crashed!' do
    it 'updates status to crashed and sets error message and completed_at' do
      freeze_time do
        tracking.mark_crashed!

        expect(tracking.status).to eq('crashed')
        expect(tracking.error_message).to include('did not update status within expected timeframe')
        expect(tracking.completed_at).to eq(Time.current)
      end
    end
  end

  describe '#duration' do
    it 'returns the duration between started_at and completed_at' do
      tracking.update!(
        started_at: Time.current - 5.minutes,
        completed_at: Time.current
      )

      expect(tracking.duration).to be_within(1.second).of(5.minutes)
    end

    it 'returns nil if started_at or completed_at is missing' do
      tracking.update!(started_at: nil, completed_at: nil)
      expect(tracking.duration).to be_nil
    end
  end

  describe '#status_label' do
    it 'returns human-readable status labels' do
      expect(build(:batch_job_tracking, status: 'pending').status_label).to eq('Waiting to start')
      expect(build(:batch_job_tracking, status: 'running').status_label).to eq('In progress')
      expect(build(:batch_job_tracking, status: 'completed').status_label).to eq('Completed successfully')
      expect(build(:batch_job_tracking, status: 'failed').status_label).to eq('Failed with error')
      expect(build(:batch_job_tracking, status: 'crashed').status_label).to eq('Crashed or killed')
    end
  end

  describe '#doc_summary' do
    it 'returns a summary of doc identifiers' do
      tracking = build(:batch_job_tracking,
                       doc_identifiers: [
                         { 'sourcedb' => 'PMC', 'sourceid' => '123' },
                         { 'sourcedb' => 'PMC', 'sourceid' => '456' }
                       ])

      expect(tracking.doc_summary).to eq('PMC:123, PMC:456')
    end

    it 'truncates long lists and shows count' do
      tracking = build(:batch_job_tracking,
                       doc_identifiers: [
                         { 'sourcedb' => 'PMC', 'sourceid' => '1' },
                         { 'sourcedb' => 'PMC', 'sourceid' => '2' },
                         { 'sourcedb' => 'PMC', 'sourceid' => '3' },
                         { 'sourcedb' => 'PMC', 'sourceid' => '4' }
                       ])

      expect(tracking.doc_summary(2)).to eq('PMC:1, PMC:2... (2 more)')
    end

    it 'returns message for empty doc_identifiers' do
      tracking = build(:batch_job_tracking, doc_identifiers: [])
      expect(tracking.doc_summary).to eq('(no docs)')
    end
  end

  describe 'cascade delete' do
    it 'deletes tracking records when parent job is deleted' do
      tracking_id = tracking.id
      parent_job.destroy

      expect(BatchJobTracking.find_by(id: tracking_id)).to be_nil
    end
  end
end
