# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateDocTextFromMediaJob, type: :job do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium, user: user) }
  let(:attributes) { { sourcedb: 'Example', sourceid: '001' } }

  describe '#perform' do
    let(:generation) { instance_double(DocGenerationFromMedia, call: nil) }

    before do
      allow(DocGenerationFromMedia).to receive(:new).and_return(generation)
    end

    it 'delegates to DocGenerationFromMedia with the given project, medium, user and attributes' do
      GenerateDocTextFromMediaJob.perform_now(project, medium, user, attributes)

      expect(DocGenerationFromMedia).to have_received(:new).with(
        project: project,
        medium: medium,
        user: user,
        attributes: attributes
      )
      expect(generation).to have_received(:call)
    end
  end

  describe '#job_name' do
    it 'returns the correct name' do
      expect(GenerateDocTextFromMediaJob.new.job_name).to eq('Generate doc text from media')
    end
  end
end
