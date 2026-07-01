# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateDocTextFromMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium, user: user) }
  let(:hdoc) { { 'sourcedb' => 'PMC', 'sourceid' => '12345', 'text' => 'original text' } }

  def setup_job_record(project)
    job_record = create(:job, organization: project)
    allow(job_record).to receive(:update_attribute)
    allow(job_record).to receive(:add_message)
    allow(job_record).to receive(:start!)
    allow(job_record).to receive(:finish!)

    allow_any_instance_of(GenerateDocTextFromMediaJob).to receive(:before_perform) do |job_instance, _active_job|
      job_instance.instance_variable_set(:@job, job_record)
    end

    job_record
  end

  describe '#perform' do
    let(:caption) { 'A generated caption.' }
    let(:doc) { create(:doc, sourcedb: 'PMC', sourceid: '12345') }
    let(:file_double) { double(path: '/tmp/fake.jpg') }

    before do
      allow(medium).to receive_message_chain(:file, :open).and_yield(file_double)
      allow(ImageCaptionService).to receive(:new).and_return(double(call: caption))
      allow(Doc).to receive(:hdoc_normalize!).and_return(hdoc.with_indifferent_access)
      allow(Doc).to receive(:store_hdoc!).and_return(doc)
      allow(project).to receive(:add_doc!)
    end

    it 'uses caption from ImageCaptionService as the doc body' do
      GenerateDocTextFromMediaJob.perform_now(project, user, hdoc, medium)

      expect(Doc).to have_received(:hdoc_normalize!).with(
        hash_including('body' => caption),
        user,
        user.root?
      )
    end

    it 'removes original text and replaces with caption' do
      GenerateDocTextFromMediaJob.perform_now(project, user, hdoc, medium)

      expect(Doc).to have_received(:hdoc_normalize!).with(
        hash_excluding('text'),
        user,
        user.root?
      )
    end

    it 'stores the doc and adds it to the project' do
      GenerateDocTextFromMediaJob.perform_now(project, user, hdoc, medium)

      expect(Doc).to have_received(:store_hdoc!)
      expect(project).to have_received(:add_doc!).with(doc)
    end
  end

  describe '#job_name' do
    it 'returns the correct name' do
      expect(GenerateDocTextFromMediaJob.new.job_name).to eq('Generate doc text from media')
    end
  end
end
