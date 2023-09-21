require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'get_project_annotations' do
    let(:doc) { create(:doc) }
    let(:project) { create(:project) }

    before do
      create(:project_doc, doc: doc, project: project)

      # denotations
      denotation1 = create(:denotation, doc: doc, project: project)
      denotation2 = create(:object_denotation, doc: doc, project: project)
      @relation1 = create(:relation, project: project, subj: denotation1, obj: denotation2, pred: 'predicate')
      @modification1 = create(:modification, project: project, obj: denotation1, pred: 'negation')
      create(:modification, project: project, obj: @relation1, pred: 'suspect')
      @attribute1 = create(:attrivute, project: project, subj: denotation1, obj: 'Protein', pred: 'type')
      create(:attrivute, project: project, subj: @relation1, obj: 'true', pred: 'negation')

      # blocks
      block1 = create(:block, doc: doc, project: project)
      block2 = create(:second_block, doc: doc, project: project)
      create(:relation, project: project, subj: block1, obj: block2, pred: 'next')
      create(:modification, project: project, obj: block1, pred: 'negation')
      create(:attrivute, project: project, subj: block1, obj: 'true', pred: 'suspect')
    end

    it 'returns an hash' do
      expect(doc.get_project_annotations(project)).to be_a(Hash)
    end

    it 'returns an hash with project' do
      expect(doc.get_project_annotations(project)[:project]).to eq('TestProject')
    end

    it 'returns an hash with denotations' do
      expect(doc.get_project_annotations(project)[:denotations]).to include(id: "T1", obj: 'subject', span: { begin: 0, end: 4 })
    end

    it 'returns an hash with blocks' do
      expect(doc.get_project_annotations(project)[:blocks]).to include(id: "B1", obj: '1st line', span: { begin: 0, end: 14 })
    end

    it 'returns an hash with relations' do
      expect(doc.get_project_annotations(project)[:relations]).to include(id: @relation1.hid, pred: 'predicate', subj: 'T1', obj: 'T2')
    end

    it 'returns an hash with modifications' do
      expect(doc.get_project_annotations(project)[:modifications]).to include(id: @modification1.hid, pred: 'negation', obj: 'T1')
    end

    it 'returns an hash with attributes' do
      expect(doc.get_project_annotations(project)[:attributes]).to include(id: @attribute1.hid, pred: 'type', subj: 'T1', obj: 'Protein')
    end
  end
end
