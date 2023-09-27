require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe '#get_annotations' do
    let!(:doc) { create(:doc) }
    let!(:project) { create(:project) }
    let!(:project_doc) { create(:project_doc, doc: doc, project: project) }

    let!(:denotation1) { create(:denotation, doc: doc, project: project) }
    let!(:attribute1) { create(:attrivute, project: project, subj: denotation1, obj: 'Protein', pred: 'type') }
    let!(:modification1) { create(:modification, project: project, obj: denotation1, pred: 'negation') }

    let!(:denotation2) { create(:object_denotation, doc: doc, project: project) }
    let!(:relation1) { create(:relation, hid: "S1", project: project, subj: denotation1, obj: denotation2, pred: 'predicate') }
    let!(:modification2) { create(:modification, project: project, obj: relation1, pred: 'suspect') }
    let!(:attribute2) { create(:attrivute, project: project, subj: relation1, obj: 'true', pred: 'negation') }

    let!(:block1) { create(:block, doc: doc, project: project) }
    let!(:attribute3) { create(:attrivute, project: project, subj: block1, obj: 'true', pred: 'suspect') }
    let!(:modification3) { create(:modification, project: project, obj: block1, pred: 'negation') }
    let!(:block2) { create(:second_block, doc: doc, project: project) }
    let!(:relation2) { create(:relation, project: project, subj: block1, obj: block2, pred: 'next') }

    let(:span) { nil }
    subject { project_doc.annotation_in span }

    it { is_expected.to be_a(Annotation) }

    it { expect(subject.project).to eq(project) }
    it { expect(subject.denotations).to include(denotation1, denotation2) }
    it { expect(subject.blocks).to include(block1, block2) }
    it { expect(subject.relations).to include(relation1, relation2) }
    it { expect(subject.attributes).to include(attribute1, attribute2, attribute3) }
    it { expect(subject.modifications).to include(modification1, modification2, modification3) }

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
