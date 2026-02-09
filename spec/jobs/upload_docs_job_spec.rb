# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadDocsJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:upload_dir) { Dir.mktmpdir }
  let(:options) { { mode: :skip } }

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(UploadDocsJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  after do
    FileUtils.remove_entry(upload_dir) if File.exist?(upload_dir)
  end

  describe '#perform' do
    context 'elasticsearch index queue' do
      it 'enqueues project memberships and schedules processing for added docs' do
        # Create a JSON doc file
        filepath = File.join(upload_dir, 'test.json')
        File.write(filepath, { sourcedb: 'TestDB', sourceid: 'doc1', text: 'Hello world.' }.to_json)

        # Stub prepare_upload_files to return our test dir directly
        allow_any_instance_of(UploadDocsJob).to receive(:prepare_upload_files).and_return(upload_dir)
        allow_any_instance_of(UploadDocsJob).to receive(:remove_upload_files)

        allow(Doc).to receive(:hdoc_normalize!) { |hdoc, _user, _root| hdoc }
        doc = create(:doc, sourcedb: 'TestDB', sourceid: 'doc1')
        allow(Doc).to receive(:store_hdoc!).and_return(doc)

        expect(Elasticsearch::IndexQueue).to receive(:add_project_memberships).with(
          doc_ids: [doc.id],
          project_id: project.id
        ).once
        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        UploadDocsJob.perform_now(project, filepath, options)
      end

      it 'enqueues all added doc IDs in a single call' do
        # Create two JSON doc files
        File.write(File.join(upload_dir, 'doc1.json'), { sourcedb: 'TestDB', sourceid: 'doc1', text: 'First.' }.to_json)
        File.write(File.join(upload_dir, 'doc2.json'), { sourcedb: 'TestDB', sourceid: 'doc2', text: 'Second.' }.to_json)

        allow_any_instance_of(UploadDocsJob).to receive(:prepare_upload_files).and_return(upload_dir)
        allow_any_instance_of(UploadDocsJob).to receive(:remove_upload_files)

        allow(Doc).to receive(:hdoc_normalize!) { |hdoc, _user, _root| hdoc }
        doc1 = create(:doc, sourcedb: 'TestDB', sourceid: 'doc1')
        doc2 = create(:doc, sourcedb: 'TestDB', sourceid: 'doc2')
        allow(Doc).to receive(:store_hdoc!).and_return(doc1, doc2)

        added_ids = nil
        allow(Elasticsearch::IndexQueue).to receive(:add_project_memberships) { |args| added_ids = args[:doc_ids] }
        allow(Elasticsearch::IndexQueue).to receive(:schedule_processing)

        UploadDocsJob.perform_now(project, 'dummy.tgz', options)

        expect(added_ids).to match_array([doc1.id, doc2.id])
      end

      it 'does not enqueue or schedule when no docs were added' do
        # Empty directory — no files to process
        allow_any_instance_of(UploadDocsJob).to receive(:prepare_upload_files).and_return(upload_dir)
        allow_any_instance_of(UploadDocsJob).to receive(:remove_upload_files)

        expect(Elasticsearch::IndexQueue).not_to receive(:add_project_memberships)
        expect(Elasticsearch::IndexQueue).not_to receive(:schedule_processing)

        UploadDocsJob.perform_now(project, 'dummy.tgz', options)
      end

      it 'enqueues and schedules for docs added before suspension' do
        job_record = setup_job_record(project)

        File.write(File.join(upload_dir, 'doc1.json'), { sourcedb: 'TestDB', sourceid: 'doc1', text: 'Hello.' }.to_json)
        File.write(File.join(upload_dir, 'doc2.json'), { sourcedb: 'TestDB', sourceid: 'doc2', text: 'World.' }.to_json)

        allow_any_instance_of(UploadDocsJob).to receive(:prepare_upload_files).and_return(upload_dir)
        allow_any_instance_of(UploadDocsJob).to receive(:remove_upload_files)

        allow(Doc).to receive(:hdoc_normalize!) { |hdoc, _user, _root| hdoc }
        doc1 = create(:doc, sourcedb: 'TestDB', sourceid: 'doc1')
        allow(Doc).to receive(:store_hdoc!).and_return(doc1)

        # Suspend after first doc is processed
        call_count = 0
        allow_any_instance_of(UploadDocsJob).to receive(:check_suspend_flag) do
          call_count += 1
          raise Exceptions::JobSuspendError if call_count == 1
        end

        expect(Elasticsearch::IndexQueue).to receive(:add_project_memberships).once
        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        UploadDocsJob.perform_now(project, 'dummy.tgz', options)
      end

      it 'does not enqueue existing docs that were skipped' do
        # Pre-create a doc already in the project
        doc = create(:doc, sourcedb: 'TestDB', sourceid: 'existing1')
        create(:project_doc, project: project, doc: doc)

        File.write(File.join(upload_dir, 'existing.json'), { sourcedb: 'TestDB', sourceid: 'existing1', text: 'Already here.' }.to_json)

        allow_any_instance_of(UploadDocsJob).to receive(:prepare_upload_files).and_return(upload_dir)
        allow_any_instance_of(UploadDocsJob).to receive(:remove_upload_files)

        allow(Doc).to receive(:hdoc_normalize!) { |hdoc, _user, _root| hdoc }

        expect(Elasticsearch::IndexQueue).not_to receive(:add_project_memberships)
        expect(Elasticsearch::IndexQueue).not_to receive(:schedule_processing)

        UploadDocsJob.perform_now(project, 'dummy.tgz', options)
      end
    end
  end
end
