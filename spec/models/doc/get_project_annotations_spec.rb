require 'rails_helper'

RSpec.describe Doc, type: :model do
   describe 'get_project_annotations' do
    let(:doc) { create(:doc) }
    let(:project) { create(:project) }

    it 'returns an array' do
      expect(doc.get_project_annotations(project)).to be_a(Hash)
    end

    it 'returns an array with project' do
      expect(doc.get_project_annotations(project)[:project]).to eq('TestProject')
    end
  end
end
