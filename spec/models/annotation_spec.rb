require 'rails_helper'

RSpec.describe Annotation, type: :model do
  describe 'as_json' do
    let(:doc) { build(:doc) }
    let(:project) { build(:project) }
    let(:option) { {} }

    let(:denotation1) { build(:denotation, doc: doc, project: project) }
    let(:denotation2) { build(:object_denotation, doc: doc, project: project) }
    let(:relation1) { build(:relation, project: project, subj: denotation1, obj: denotation2, pred: 'predicate') }
    let(:modification1) { build(:modification, project: project, obj: denotation1, pred: 'negation') }
    let(:attribute1) { build(:attrivute, project: project, subj: denotation1, obj: 'Protein', pred: 'type') }

    let(:block1) { build(:block, doc: doc, project: project) }
    let(:block2) { build(:second_block, doc: doc, project: project) }
    let(:relation2) { build(:relation, hid: "S1", project: project, subj: block1, obj: block2, pred: 'next') }
    let(:modification2) { build(:modification, project: project, obj: block1, pred: 'negation') }
    let(:attribute2) { build(:attrivute, project: project, subj: block1, obj: 'true', pred: 'suspect') }

    subject do
      Annotation.new(project,
                     [denotation2, denotation1],
                     [block2, block1],
                     [relation2, relation1],
                     [attribute1, attribute2],
                     ).as_json(option)
    end

    it { is_expected.to be_a(Hash) }

    it { expect(subject[:project]).to eq(project.name) }

    # Denotations are sorted by creation order
    it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
    it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }

    # Blocks are sorted by creation order
    it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }
    it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }

    it { expect(subject[:relations].first).to eq(id: relation2.hid, pred: 'next', subj: 'B1', obj: 'B2') }
    it { expect(subject[:relations].second).to eq(id: relation1.hid, pred: 'predicate', subj: 'T1', obj: 'T2') }

    it { expect(subject[:attributes]).to include(id: attribute1.hid, pred: 'type', subj: 'T1', obj: 'Protein') }

    context 'sort option is specified' do
      let(:option) { { is_sort: true } }

      it { expect(subject[:denotations].first).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }
      it { expect(subject[:denotations].second).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
      it { expect(subject[:blocks].first).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }
      it { expect(subject[:blocks].second).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }

      # Relations are sorted by hid in string order
      it { expect(subject[:relations].first).to eq(id: relation1.hid,  pred: 'predicate', subj: 'T1', obj: 'T2') }
      it { expect(subject[:relations].second).to eq(id: relation2.hid, pred: 'next', subj: 'B1', obj: 'B2') }
    end

    context 'is_bag_denotations is specified' do
      let(:option) { { is_bag_denotations: true } }

      it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
      it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }
      it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }
      it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }
      it { expect(subject[:relations].first).to eq(id: relation2.hid, pred: 'next', subj: 'B1', obj: 'B2') }
    end

    context 'span is specified' do
      let(:option)  { { span: { begin: 8, end: 14 } } }

      it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 2, end: 6 }) }
      it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: -8, end: -4 }) }
      it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 8, end: 29 }) }
      it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: -8, end: 6 }) }

      context 'context_size is specified' do
        let(:option) do
          {
            span: { begin: 8, end: 14 },
            context_size: 6
          }
        end

        it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 8, end: 12 }) }
        it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: -2, end: 2 }) }
        it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 14, end: 35 }) }
        it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: -2, end: 12 }) }

        context 'context_size equals to begin of the span' do
          let(:option) do
            {
              span: { begin: 8, end: 14 },
              context_size:8
            }
          end

          it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
          it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }
          it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }
          it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }
        end

        context "context_size is bigger than begin of span " do
          let(:option) do
            {
              span: { begin: 8, end: 14 },
              context_size: 10
            }
          end

          it { expect(subject[:denotations].first).to eq(id: "T2", obj: 'object', span: { begin: 10, end: 14 }) }
          it { expect(subject[:denotations].second).to eq(id: "T1", obj: 'subject', span: { begin: 0, end: 4 }) }
          it { expect(subject[:blocks].first).to eq(id: "B2", obj: '2nd line', span: { begin: 16, end: 37 }) }
          it { expect(subject[:blocks].second).to eq(id: "B1", obj: '1st line', span: { begin: 0, end: 14 }) }
        end
      end
    end
  end
end
