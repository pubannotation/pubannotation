require 'rails_helper'

RSpec.describe Doc, type: :model do
   describe 'get_project_annotations' do
     let(:doc) { create(:doc) }
     let(:project) { create(:project) }

    before do
      create(:project_doc, doc: doc, project: project)
      create(:denotation, doc: doc, project: project)
      create(:block, doc: doc, project: project)
    end

    it 'returns an hash' do
      expect(doc.get_project_annotations(project)).to be_a(Hash)
    end

    it 'returns an hash with project' do
      expect(doc.get_project_annotations(project)[:project]).to eq('TestProject')
    end

    it 'returns an hash with denotations' do
      expect(doc.get_project_annotations(project)[:denotations]).to include(id: "T1", obj: 'subject', span: {begin: 0, end: 4})
    end

     it 'returns an hash with blocks' do
        expect(doc.get_project_annotations(project)[:blocks]).to include(id: "B1", obj: '1st line', span: {begin: 0, end: 14})
     end
  end
end
