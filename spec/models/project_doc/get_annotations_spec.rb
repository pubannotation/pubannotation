require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe '#get_annotations' do
    let!(:doc) { create(:doc) }
    let!(:project) { create(:project) }
    let!(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }

    let!(:denotation2) { create(:object_denotation, doc: doc, project: project) }
    let!(:denotation1) { create(:denotation, doc: doc, project: project) }
    let!(:relation1) { create(:relation, hid: "S1", project: project, subj: denotation1, obj: denotation2, pred: 'predicate') }
    let!(:modification1) { create(:modification, project: project, obj: denotation1, pred: 'negation') }
    let!(:attribute1) { create(:attrivute, project: project, subj: denotation1, obj: 'Protein', pred: 'type') }

    let!(:block2) { create(:second_block, doc: doc, project: project) }
    let!(:block1) { create(:block, doc: doc, project: project) }
    let!(:relation2) { create(:relation, project: project, subj: block1, obj: block2, pred: 'next') }

    before do
      create(:modification, project: project, obj: block1, pred: 'negation')
      create(:attrivute, project: project, subj: block1, obj: 'true', pred: 'suspect')
      create(:modification, project: project, obj: relation1, pred: 'suspect')
      create(:attrivute, project: project, subj: relation1, obj: 'true', pred: 'negation')
    end

    subject { project_doc.get_annotations(span) }

    it { is_expected.to be_a(Annotation) }

    it { expect(subject.project).to eq(project) }

    # Denotations are sorted by creation order
    it { expect(subject.denotations.first).to eq(denotation2) }
    it { expect(subject.denotations.second).to eq(denotation1) }

    # Blocks are sorted by creation order
    it { expect(subject.blocks.first).to eq(block2) }
    it { expect(subject.blocks.second).to eq(block1) }

    it { expect(subject.relations.first).to eq(relation1) }
    it { expect(subject.relations.second).to eq(relation2) }

    it { expect(subject.modifications).to include(modification1) }
    it { expect(subject.attributes).to include(attribute1) }

    context 'span is specified' do
      let(:span) { { begin: 0, end: 4 } }

      it { expect(subject.denotations).to include(denotation1) }
      it { expect(subject.blocks).to be_empty }
      it { expect(subject.relations).to be_empty }
      it { expect(subject.modifications).to include(modification1) }
      it { expect(subject.attributes).to include(attribute1) }

      context 'no annotation among span' do
        let(:span) { { begin: 100, end: 200 } }

        it { expect(subject.denotations).to be_empty }
        it { expect(subject.blocks).to be_empty }
        it { expect(subject.relations).to be_empty }
        it { expect(subject.modifications).to be_empty }
        it { expect(subject.attributes).to be_empty }
      end
    end
  end
end
