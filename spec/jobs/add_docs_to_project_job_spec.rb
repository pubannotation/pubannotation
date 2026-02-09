# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddDocsToProjectJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(AddDocsToProjectJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  describe '#perform' do
    context 'counter accuracy' do
      it 'does not double-count project docs_count' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }, { sourcedb: 'PMC', sourceid: '222' }]

        allow(project).to receive(:add_docs).and_return([2, 2, []])
        allow(Project).to receive(:docs_stat_increment!)
        allow(Project).to receive(:docs_count_increment!)

        # add_docs already calls project.increment!(:docs_count, 2) internally.
        # The job must NOT call it again.
        expect(project).not_to receive(:increment!).with(:docs_count, anything)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'does not double-count project docs_stat' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_return([1, 1, []])
        allow(Project).to receive(:docs_stat_increment!)
        allow(Project).to receive(:docs_count_increment!)

        # add_docs already calls project.docs_stat_increment! internally.
        # The job must NOT call it again.
        expect(project).not_to receive(:docs_stat_increment!)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end
    end

    context 'class-level admin project counters' do
      it 'updates admin counters per-sourcedb with correct counts' do
        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PMC', sourceid: '222' },
          { sourcedb: 'PubMed', sourceid: '333' }
        ]

        # PMC: 2 added, 2 sequenced; PubMed: 1 added, 1 sequenced
        call_count = 0
        allow(project).to receive(:add_docs) do |index|
          call_count += 1
          if index.db == 'PMC'
            [2, 2, []]
          else
            [1, 1, []]
          end
        end

        # Each sourcedb should get its OWN sequenced count, not the global total
        expect(Project).to receive(:docs_stat_increment!).with('PMC', 2).once
        expect(Project).to receive(:docs_stat_increment!).with('PubMed', 1).once
        expect(Project).to receive(:docs_count_increment!).with(2).once
        expect(Project).to receive(:docs_count_increment!).with(1).once

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'skips admin counter update when no docs were sequenced' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        # 1 added (already existed in DB), 0 sequenced
        allow(project).to receive(:add_docs).and_return([1, 0, []])

        expect(Project).not_to receive(:docs_stat_increment!)
        expect(Project).not_to receive(:docs_count_increment!)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'updates admin counters only for sourcedbs that had sequenced docs' do
        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PubMed', sourceid: '222' }
        ]

        allow(project).to receive(:add_docs) do |index|
          if index.db == 'PMC'
            [1, 1, []]  # 1 sequenced
          else
            [1, 0, []]  # 0 sequenced (already in DB)
          end
        end

        expect(Project).to receive(:docs_stat_increment!).with('PMC', 1).once
        expect(Project).to receive(:docs_count_increment!).with(1).once
        # PubMed should NOT trigger admin updates
        expect(Project).not_to receive(:docs_stat_increment!).with('PubMed', anything)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end
    end

    context 'error handling' do
      it 'records error and continues with next sourcedb on failure' do
        job_record = setup_job_record(project)

        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PubMed', sourceid: '222' }
        ]

        call_count = 0
        allow(project).to receive(:add_docs) do |index|
          call_count += 1
          raise 'API timeout' if index.db == 'PMC'
          [1, 1, []]
        end

        AddDocsToProjectJob.perform_now(project, docspecs)

        expect(call_count).to eq(2)
        expect(job_record).to have_received(:add_message).with(
          sourcedb: 'PMC',
          sourceid: ['111'],
          body: 'API timeout'
        )
      end

      it 'does not update admin counters for failed sourcedbs' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_raise('API error')

        expect(Project).not_to receive(:docs_stat_increment!)
        expect(Project).not_to receive(:docs_count_increment!)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end
    end

    context 'progress tracking' do
      it 'updates num_dones by docspecs count per sourcedb group' do
        job_record = setup_job_record(project)

        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PMC', sourceid: '222' },
          { sourcedb: 'PubMed', sourceid: '333' }
        ]

        allow(project).to receive(:add_docs).and_return([1, 0, []])

        AddDocsToProjectJob.perform_now(project, docspecs)

        # After PMC group (2 docspecs): i = 2
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 2)
        # After PubMed group (1 docspec): i = 3
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 3)
      end
    end

    context 'elasticsearch index queue' do
      it 'schedules processing after docs are added' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_return([1, 0, []])

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'does not schedule processing when no docs were added' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_return([0, 0, []])

        expect(Elasticsearch::IndexQueue).not_to receive(:schedule_processing)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'does not schedule processing when all sourcedbs failed' do
        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_raise('API error')

        expect(Elasticsearch::IndexQueue).not_to receive(:schedule_processing)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'schedules processing even when job is suspended after adding docs' do
        job_record = setup_job_record(project)

        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PubMed', sourceid: '222' }
        ]

        # First sourcedb succeeds, then job is suspended
        allow(project).to receive(:add_docs) do |index|
          if index.db == 'PMC'
            [1, 0, []]
          else
            [1, 0, []]
          end
        end

        # Suspend after first iteration
        call_count = 0
        allow_any_instance_of(AddDocsToProjectJob).to receive(:check_suspend_flag) do
          call_count += 1
          raise Exceptions::JobSuspendError if call_count == 1
        end

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        # UseJobRecordConcern's rescue_from handles JobSuspendError
        allow(job_record).to receive(:add_message)
        allow(job_record).to receive(:finish!)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end

      it 'schedules processing when an unexpected error occurs after adding some docs' do
        job_record = setup_job_record(project)

        docspecs = [
          { sourcedb: 'PMC', sourceid: '111' },
          { sourcedb: 'PubMed', sourceid: '222' }
        ]

        call_count = 0
        allow(project).to receive(:add_docs) do |index|
          call_count += 1
          # First sourcedb succeeds, second raises an unhandled error
          raise 'unexpected crash' if call_count == 2
          [1, 0, []]
        end

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        allow(job_record).to receive(:add_message)
        allow(job_record).to receive(:finish!)

        AddDocsToProjectJob.perform_now(project, docspecs)
      end
    end

    context 'ensure block' do
      it 'reports existed docs count when some docs already existed' do
        job_record = setup_job_record(project)

        # Pre-create a doc already in the project
        doc = create(:doc, sourcedb: 'PMC', sourceid: '111')
        create(:project_doc, project: project, doc: doc)

        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }, { sourcedb: 'PMC', sourceid: '222' }]

        allow(project).to receive(:add_docs).and_return([1, 1, []])

        AddDocsToProjectJob.perform_now(project, docspecs)

        expect(job_record).to have_received(:add_message).with(
          body: '1 doc(s) existed. 1 doc(s) added.'
        )
      end

      it 'does not report when no docs previously existed' do
        job_record = setup_job_record(project)

        docspecs = [{ sourcedb: 'PMC', sourceid: '111' }]

        allow(project).to receive(:add_docs).and_return([1, 1, []])

        AddDocsToProjectJob.perform_now(project, docspecs)

        expect(job_record).not_to have_received(:add_message).with(
          hash_including(body: /existed/)
        )
      end
    end
  end

  describe '#job_name' do
    it 'returns a descriptive name' do
      job = AddDocsToProjectJob.new(project, [])
      expect(job.job_name).to eq('Add docs to project')
    end
  end
end
