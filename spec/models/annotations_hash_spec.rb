require 'rails_helper'

RSpec.describe AnnotationsHash, type: :model do
  describe 'to_hash' do
    let!(:doc) { create(:doc) }
    let!(:project) { create(:project) }
    let!(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }
    let(:context_size) { nil }
    let(:is_sort) { false }
    let(:is_full) { false }
    let(:is_bag_denotations) { false }
    let(:has_track) { false }

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

    subject { AnnotationsHash.new(doc, span, context_size, is_sort, is_full, is_bag_denotations, [project_doc], has_track).to_hash }

    it { is_expected.to be_a(Hash) }

    it { expect(subject[:project]).to eq('TestProject') }

    # Denotations are sorted by creation order
    it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
    it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }

    # Blocks are sorted by creation order
    it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }
    it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }

    it { expect(subject[:relations].first).to eq(id: relation1.hid, pred: 'predicate', subj: 'T1', obj: 'T2') }
    it { expect(subject[:relations].second).to eq(id: relation2.hid, pred: 'next', subj: 'B1', obj: 'B2') }

    it { expect(subject[:modifications]).to include(id: modification1.hid, pred: 'negation', obj: 'T1') }
    it { expect(subject[:attributes]).to include(id: attribute1.hid, pred: 'type', subj: 'T1', obj: 'Protein') }

    context 'sort option is specified' do
      let(:is_sort) { true }

      it { expect(subject[:denotations].first).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }
      it { expect(subject[:denotations].second).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
      it { expect(subject[:blocks].first).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }
      it { expect(subject[:blocks].second).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }

      # Relations are sorted by hid in string order
      it { expect(subject[:relations].first).to eq(id: relation2.hid, pred: 'next', subj: 'B1', obj: 'B2') }
      it { expect(subject[:relations].second).to eq(id: relation1.hid, pred: 'predicate', subj: 'T1', obj: 'T2') }
    end

  end
end
