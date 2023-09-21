require 'rails_helper'

RSpec.describe Doc, type: :model do
   describe 'get_project_annotations' do
     let(:doc) { create(:doc) }
     let(:project) { create(:project) }

    before do
      create(:project_doc, doc: doc, project: project)
      denotation1 = create(:denotation, doc: doc, project: project)
      denotation2 = create(:object_denotation, doc: doc, project: project)
      @relation1 = create(:relation, project: project, subj: denotation1, obj: denotation2, pred: 'predicate')

      block1 = create(:block, doc: doc, project: project)
      block2 = create(:second_block, doc: doc, project: project)
      create(:relation, project: project, subj: block1, obj: block2, pred: 'next')
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

     it 'returns an hash with relations' do
        expect(doc.get_project_annotations(project)[:relations]).to include(id: @relation1.hid, pred: 'predicate', subj: 'T1', obj: 'T2')
     end
  end
end
