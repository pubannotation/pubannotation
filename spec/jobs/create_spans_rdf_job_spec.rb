# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateSpansRdfJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  def create_project_doc(project)
    doc = create(:doc)
    create(:project_doc, project: project, doc: doc)
    doc
  end

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(CreateSpansRdfJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  describe 'PROGRESS_UPDATE_INTERVAL' do
    it 'is set to 10' do
      expect(CreateSpansRdfJob::PROGRESS_UPDATE_INTERVAL).to eq(10)
    end
  end

  describe '#perform' do
    context 'progress updates' do
      it 'updates progress only at intervals and on the final doc' do
        num_docs = 25
        docs = num_docs.times.map { create_project_doc(project) }

        job_record = setup_job_record(project)

        allow(project).to receive(:create_spans_RDF) do |_in_collection, _loc, &block|
          num_docs.times { |i| block.call(i, docs[i], nil) }
        end

        CreateSpansRdfJob.perform_now(project, nil)

        # Should update at i+1 = 10, 20, and 25 (final)
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 10)
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 20)
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 25)

        # Should NOT update at every single doc
        expect(job_record).not_to have_received(:update_attribute).with(:num_dones, 1)
        expect(job_record).not_to have_received(:update_attribute).with(:num_dones, 5)
      end

      it 'always updates on the final doc even if not on interval' do
        num_docs = 3
        docs = num_docs.times.map { create_project_doc(project) }

        job_record = setup_job_record(project)

        allow(project).to receive(:create_spans_RDF) do |_in_collection, _loc, &block|
          num_docs.times { |i| block.call(i, docs[i], nil) }
        end

        CreateSpansRdfJob.perform_now(project, nil)

        # Only the final update since no interval boundary is hit
        expect(job_record).to have_received(:update_attribute).with(:num_dones, 3)
        expect(job_record).not_to have_received(:update_attribute).with(:num_dones, 1)
        expect(job_record).not_to have_received(:update_attribute).with(:num_dones, 2)
      end
    end

    context 'error messages' do
      it 'records error messages from the block' do
        doc = create_project_doc(project)

        job_record = setup_job_record(project)

        allow(project).to receive(:create_spans_RDF) do |_in_collection, _loc, &block|
          block.call(0, doc, 'failure during rdfization: some error')
        end

        expect(job_record).to receive(:add_message).with(
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          body: 'failure during rdfization: some error'
        )

        CreateSpansRdfJob.perform_now(project, nil)
      end
    end
  end

  describe '#job_name' do
    it 'returns a descriptive name' do
      job = CreateSpansRdfJob.new(project, nil)
      allow(job).to receive(:resource_name).and_return(project.name)
      expect(job.job_name).to eq("Create Spans RDF - #{project.name}")
    end
  end
end
