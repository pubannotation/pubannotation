# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessAnnotationsBatchJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:parent_job) { create(:job, organization: project) }
  let!(:doc1) { create(:doc, sourcedb: 'PMC', sourceid: '123', body: 'Sample text for doc1.') }
  let!(:doc2) { create(:doc, sourcedb: 'PMC', sourceid: '456', body: 'Another sample text for doc2.') }
  let!(:project_doc1) { create(:project_doc, project: project, doc: doc1) }
  let!(:project_doc2) { create(:project_doc, project: project, doc: doc2) }

  describe 'batch counter updates' do
    let(:tracking) { create(:batch_job_tracking, parent_job_id: parent_job.id, status: 'pending') }

    context 'in add mode' do
      let(:options) { { mode: 'add' } }
      let(:annotation_transaction) do
        [
          {
            sourcedb: 'PMC',
            sourceid: '123',
            text: 'Sample text for doc1.',
            denotations: [
              { id: 'T1', span: { begin: 0, end: 6 }, obj: 'Protein' },
              { id: 'T2', span: { begin: 7, end: 11 }, obj: 'Gene' }
            ],
            relations: []
          },
          {
            sourcedb: 'PMC',
            sourceid: '456',
            text: 'Another sample text for doc2.',
            denotations: [
              { id: 'T3', span: { begin: 0, end: 7 }, obj: 'Chemical' }
            ],
            blocks: [],
            relations: []
          }
        ]
      end

      it 'increments project_doc counters correctly' do
        # Set initial values
        project_doc1.update!(denotations_num: 10, blocks_num: 0, relations_num: 0)
        project_doc2.update!(denotations_num: 8, blocks_num: 0, relations_num: 0)

        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        # In add mode, counters are incremented
        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(12)  # 10 + 2 new

        project_doc2.reload
        expect(project_doc2.denotations_num).to eq(9)   # 8 + 1 new
      end

      it 'increments doc counters correctly (cross-project aggregates)' do
        # Set initial values (simulating annotations from other projects)
        doc1.update!(denotations_num: 50, blocks_num: 0, relations_num: 0)
        doc2.update!(denotations_num: 30, blocks_num: 0, relations_num: 0)

        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        # In add mode, net delta = new annotations (old = 0)
        doc1.reload
        expect(doc1.denotations_num).to eq(52)  # 50 + 2 new

        doc2.reload
        expect(doc2.denotations_num).to eq(31)  # 30 + 1 new
      end

      it 'creates new annotations in database' do
        initial_denotation_count = Denotation.where(project: project).count

        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        expect(Denotation.where(project: project).count).to eq(initial_denotation_count + 3)
      end
    end

    context 'in replace mode' do
      let(:options) { { mode: 'replace' } }
      let(:annotation_transaction) do
        [
          {
            sourcedb: 'PMC',
            sourceid: '123',
            text: 'Sample text for doc1.',
            denotations: [
              { id: 'T1', span: { begin: 0, end: 6 }, obj: 'Protein' },
              { id: 'T2', span: { begin: 7, end: 11 }, obj: 'Gene' },
              { id: 'T3', span: { begin: 12, end: 15 }, obj: 'Drug' }
            ],
            blocks: [],
            relations: []
          }
        ]
      end

      before do
        # Create existing annotations that will be replaced
        create(:denotation, project: project, doc: doc1, hid: 'OLD1')
        create(:denotation, project: project, doc: doc1, hid: 'OLD2')

        # Set counters to reflect existing annotations
        project_doc1.update!(denotations_num: 2, blocks_num: 0, relations_num: 0)

        # Doc has annotations from multiple projects (simulate cross-project)
        doc1.update!(denotations_num: 20, blocks_num: 0, relations_num: 0)
      end

      it 'sets project_doc counters to new values (not increment)' do
        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        # In replace mode, project_doc counters are SET to new values
        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(3)   # SET to 3 (new count)
      end

      it 'increments doc counters by net delta (new - old)' do
        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        # In replace mode, doc counters increment by net delta
        # Net delta: (3 new - 2 old) = +1 denotation
        doc1.reload
        expect(doc1.denotations_num).to eq(21)  # 20 + (3 - 2) = 21
      end

      it 'deletes old annotations and creates new ones' do
        old_denotation_ids = Denotation.where(project: project, doc: doc1).pluck(:id)

        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        # Old annotations should be deleted
        old_denotation_ids.each do |id|
          expect(Denotation.exists?(id)).to be false
        end

        # New annotations should exist
        new_denotations = Denotation.where(project: project, doc: doc1)
        expect(new_denotations.count).to eq(3)
      end

    end

    context 'cross-project scenario' do
      let(:project_a) { create(:project, user: user, name: 'ProjectA') }
      let(:project_b) { create(:project, user: user, name: 'ProjectB') }
      let(:shared_doc) { create(:doc, sourcedb: 'PMC', sourceid: '999', body: 'Shared document text.') }
      let!(:project_doc_a) { create(:project_doc, project: project_a, doc: shared_doc) }
      let!(:project_doc_b) { create(:project_doc, project: project_b, doc: shared_doc) }
      let(:parent_job_a) { create(:job, organization: project_a) }
      let(:tracking_a) { create(:batch_job_tracking, parent_job_id: parent_job_a.id, status: 'pending') }
      let(:options) { { mode: 'replace' } }

      before do
        # ProjectA has 50 denotations on shared_doc
        create_list(:denotation, 50, project: project_a, doc: shared_doc)
        project_doc_a.update!(denotations_num: 50, blocks_num: 0, relations_num: 0)

        # ProjectB has 30 denotations on shared_doc
        create_list(:denotation, 30, project: project_b, doc: shared_doc)
        project_doc_b.update!(denotations_num: 30, blocks_num: 0, relations_num: 0)

        # Doc aggregate: 80 total denotations
        shared_doc.update!(denotations_num: 80, blocks_num: 0, relations_num: 0)
      end

      it 'correctly updates doc aggregate when ProjectA replaces its annotations' do
        # ProjectA uploads 60 new denotations (was 50, now 60)
        new_annotations = [{
          sourcedb: 'PMC',
          sourceid: '999',
          text: 'Shared document text.',
          denotations: Array.new(60) { |i| { id: "T#{i}", span: { begin: 0, end: 6 }, obj: 'Protein' } },
          blocks: [],
          relations: []
        }]

        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project_a,
            new_annotations,
            options,
            parent_job_a.id,
            tracking_a.id
          )
        end

        # ProjectA's project_doc: SET to 60
        project_doc_a.reload
        expect(project_doc_a.denotations_num).to eq(60)

        # ProjectB's project_doc: unchanged
        project_doc_b.reload
        expect(project_doc_b.denotations_num).to eq(30)

        # Doc aggregate: 80 + (60 - 50) = 90
        shared_doc.reload
        expect(shared_doc.denotations_num).to eq(90)
      end

    end

    context 'tracking status' do
      let(:options) { { mode: 'add' } }
      let(:annotation_transaction) do
        [{
          sourcedb: 'PMC',
          sourceid: '123',
          text: 'Sample text for doc1.',
          denotations: [{ id: 'T1', span: { begin: 0, end: 6 }, obj: 'Protein' }],
          blocks: [],
          relations: []
        }]
      end

      it 'marks tracking as completed after successful processing' do
        perform_enqueued_jobs do
          ProcessAnnotationsBatchJob.perform_now(
            project,
            annotation_transaction,
            options,
            parent_job.id,
            tracking.id
          )
        end

        tracking.reload
        expect(tracking.status).to eq('completed')
        expect(tracking.completed_at).to be_present
      end
    end
  end
end
