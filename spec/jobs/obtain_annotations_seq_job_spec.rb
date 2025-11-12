# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObtainAnnotationsSeqJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let!(:doc1) { create(:doc, sourcedb: 'PMC', sourceid: '123', body: 'Sample text for doc1.') }
  let!(:doc2) { create(:doc, sourcedb: 'PMC', sourceid: '456', body: 'Another sample text for doc2.') }
  let!(:doc3) { create(:doc, sourcedb: 'PMC', sourceid: '789', body: 'Third document text.') }
  let!(:project_doc1) { create(:project_doc, project: project, doc: doc1) }
  let!(:project_doc2) { create(:project_doc, project: project, doc: doc2) }
  let!(:project_doc3) { create(:project_doc, project: project, doc: doc3) }

  let(:annotator) { double('Annotator', name: 'test_annotator') }
  let(:filepath) { File.join('tmp', 'test_docids.txt') }
  let(:options) { { mode: :add } }

  before do
    # Create a temporary file with doc IDs
    File.open(filepath, 'w') do |f|
      f.puts(doc1.id)
      f.puts(doc2.id)
      f.puts(doc3.id)
    end

    # Mock the annotator
    allow(Annotator).to receive(:find_by_name).with('test_annotator').and_return(annotator)
    allow(annotator).to receive(:obtain_annotations_for_a_doc).and_return({
      text: 'Sample text',
      denotations: [
        { id: 'T1', span: { begin: 0, end: 6 }, obj: 'Protein' }
      ]
    })
  end

  after do
    File.delete(filepath) if File.exist?(filepath)
  end

  describe '#perform' do
    context 'successful execution' do
      before do
        allow_any_instance_of(ProjectDoc).to receive(:save_annotations).and_return([])
      end

      it 'processes all documents sequentially' do
        expect(annotator).to receive(:obtain_annotations_for_a_doc).exactly(3).times

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end

      it 'updates progress periodically' do
        job_record = create(:job, organization: project)

        # Set the @job instance variable
        allow_any_instance_of(ObtainAnnotationsSeqJob).to receive(:prepare_progress_record) do |job_instance|
          job_instance.instance_variable_set(:@job, job_record)
        end

        # Allow other update_attribute calls (like ended_at from after_perform)
        allow(job_record).to receive(:update_attribute).and_call_original

        # Expect num_dones updates specifically
        expect(job_record).to receive(:update_attribute).with(:num_dones, anything).at_least(:once).and_call_original

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end

      it 'processes documents in order from the file' do
        call_order = []

        allow(annotator).to receive(:obtain_annotations_for_a_doc) do |doc|
          call_order << doc[:sourceid]
          { text: doc[:text], denotations: [] }
        end

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end

        expect(call_order).to eq(['123', '456', '789'])
      end
    end

    context 'error handling' do
      before do
        allow_any_instance_of(ProjectDoc).to receive(:save_annotations).and_return([])
      end

      it 'continues processing after a single document error' do
        call_count = 0

        allow(annotator).to receive(:obtain_annotations_for_a_doc) do
          call_count += 1
          raise 'API Error' if call_count == 2  # Fail on second doc
          { text: 'Sample', denotations: [] }
        end

        job_record = create(:job, organization: project)
        allow_any_instance_of(ObtainAnnotationsSeqJob).to receive(:prepare_progress_record) do |job_instance|
          job_instance.instance_variable_set(:@job, job_record)
        end
        allow(job_record).to receive(:add_message)
        allow(job_record).to receive(:update_attribute)

        expect(annotator).to receive(:obtain_annotations_for_a_doc).exactly(3).times

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end

      it 'records error messages for failed documents' do
        allow(annotator).to receive(:obtain_annotations_for_a_doc).and_raise('Annotation service error')

        job_record = create(:job, organization: project)
        allow_any_instance_of(ObtainAnnotationsSeqJob).to receive(:prepare_progress_record) do |job_instance|
          job_instance.instance_variable_set(:@job, job_record)
        end
        allow(job_record).to receive(:update_attribute)

        expect(job_record).to receive(:add_message).with(
          hash_including(body: 'Annotation service error')
        ).at_least(:once)

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end
    end

    context 'batch processing' do
      let(:large_filepath) { File.join('tmp', 'large_test_docids.txt') }

      before do
        # Create 250 docs to test batch processing (BATCH_SIZE = 100)
        docs = []
        250.times do |i|
          doc = create(:doc, sourcedb: 'PMC', sourceid: "batch_#{i}", body: "Text #{i}")
          create(:project_doc, project: project, doc: doc)
          docs << doc
        end

        # Write doc IDs to file
        File.open(large_filepath, 'w') do |f|
          docs.each { |d| f.puts(d.id) }
        end

        allow_any_instance_of(ProjectDoc).to receive(:save_annotations).and_return([])
      end

      after do
        File.delete(large_filepath) if File.exist?(large_filepath)
      end

      it 'processes documents in batches' do
        expect(annotator).to receive(:obtain_annotations_for_a_doc).exactly(250).times

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, large_filepath, 'test_annotator', options)
        end
      end
    end

    context 'suspension check' do
      before do
        allow_any_instance_of(ProjectDoc).to receive(:save_annotations).and_return([])
      end

      it 'checks suspension flag after each document' do
        job_record = create(:job, organization: project)
        allow_any_instance_of(ObtainAnnotationsSeqJob).to receive(:prepare_progress_record) do |job_instance|
          job_instance.instance_variable_set(:@job, job_record)
        end
        allow(job_record).to receive(:update_attribute)

        # Mock check_suspend_flag to be called
        expect_any_instance_of(ObtainAnnotationsSeqJob).to receive(:check_suspend_flag).at_least(3).times

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end
    end

    context 'annotation saving' do
      it 'saves annotations for each document' do
        annotations = {
          text: 'Sample text',
          denotations: [
            { id: 'T1', span: { begin: 0, end: 6 }, obj: 'Protein' }
          ]
        }

        allow(annotator).to receive(:obtain_annotations_for_a_doc).and_return(annotations)

        # Use a counter to track calls instead of setting expectations on multiple instances
        call_count = 0
        allow_any_instance_of(ProjectDoc).to receive(:save_annotations) do |_, annotations_arg, options_arg|
          call_count += 1
          expect(annotations_arg).to eq(annotations)
          expect(options_arg).to eq(options)
          []
        end

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end

        expect(call_count).to eq(3)
      end

      it 'adds messages from save_annotations to job' do
        messages = [
          { body: 'Warning: some issue' },
          { body: 'Info: processed successfully' }
        ]

        allow(annotator).to receive(:obtain_annotations_for_a_doc).and_return({
          text: 'Sample', denotations: []
        })
        allow_any_instance_of(ProjectDoc).to receive(:save_annotations).and_return(messages)

        job_record = create(:job, organization: project)
        allow_any_instance_of(ObtainAnnotationsSeqJob).to receive(:prepare_progress_record) do |job_instance|
          job_instance.instance_variable_set(:@job, job_record)
        end
        allow(job_record).to receive(:update_attribute)

        expect(job_record).to receive(:add_message).with({ body: 'Warning: some issue' }).at_least(:once)
        expect(job_record).to receive(:add_message).with({ body: 'Info: processed successfully' }).at_least(:once)

        perform_enqueued_jobs do
          ObtainAnnotationsSeqJob.perform_now(project, filepath, 'test_annotator', options)
        end
      end
    end
  end

  describe '#job_name' do
    it 'returns a descriptive job name' do
      job = ObtainAnnotationsSeqJob.new(project, filepath, 'test_annotator', options)
      expect(job.job_name).to eq('Obtain annotations: test_annotator')
    end
  end
end
