# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportDocsJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:source_project) { create(:project, user: user) }

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(ImportDocsJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  describe '#perform' do
    context 'elasticsearch index queue' do
      it 'schedules ES processing after importing docs' do
        allow(project).to receive(:import_docs_from_another_project).and_return(10)

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        ImportDocsJob.perform_now(project, source_project.id)
      end

      it 'schedules ES processing even when import raises an error' do
        job_record = setup_job_record(project)

        allow(project).to receive(:import_docs_from_another_project).and_raise('DB error')

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        allow(job_record).to receive(:add_message)
        allow(job_record).to receive(:finish!)

        ImportDocsJob.perform_now(project, source_project.id)
      end

      it 'schedules ES processing even when zero docs are imported' do
        allow(project).to receive(:import_docs_from_another_project).and_return(0)

        expect(Elasticsearch::IndexQueue).to receive(:schedule_processing).once

        ImportDocsJob.perform_now(project, source_project.id)
      end
    end
  end
end
