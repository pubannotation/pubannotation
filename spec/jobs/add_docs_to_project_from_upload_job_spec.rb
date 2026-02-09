# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddDocsToProjectFromUploadJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:filepath) { File.join('tmp', 'test_upload_docids.txt') }

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(AddDocsToProjectFromUploadJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  after do
    File.delete(filepath) if File.exist?(filepath)
  end

  describe '#perform' do
    context 'elasticsearch index queue' do
      it 'schedules processing after docs are added' do
        File.write(filepath, "111\n222\n")

        allow(project).to receive(:add_docs).and_return([2, 2, []])

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        AddDocsToProjectFromUploadJob.perform_now(project, 'PMC', filepath)
      end

      it 'does not schedule processing when no docs were added' do
        File.write(filepath, "111\n")

        allow(project).to receive(:add_docs).and_return([0, 0, []])

        expect(Elasticsearch::IndexQueue).not_to receive(:schedule_processing)

        AddDocsToProjectFromUploadJob.perform_now(project, 'PMC', filepath)
      end

      it 'schedules processing even when job is suspended after adding docs' do
        job_record = setup_job_record(project)

        # Need > 1000 lines to trigger in-loop add_docs before suspension
        File.open(filepath, 'w') { |f| 1002.times { |i| f.puts(i.to_s) } }

        allow(project).to receive(:add_docs).and_return([1000, 0, []])

        # Suspend after the first batch of 1000 is processed
        call_count = 0
        allow_any_instance_of(AddDocsToProjectFromUploadJob).to receive(:check_suspend_flag) do
          call_count += 1
          raise Exceptions::JobSuspendError if call_count == 1001
        end

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        AddDocsToProjectFromUploadJob.perform_now(project, 'PMC', filepath)
      end
    end
  end

  describe '#job_name' do
    it 'returns a descriptive name' do
      job = AddDocsToProjectFromUploadJob.new(project, 'PMC', filepath)
      expect(job.job_name).to eq('Add docs to project from upload')
    end
  end
end
