require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe 'get_denotations' do
    subject { project_doc.send(:get_denotations_in, span) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }

    it { is_expected.to be_a(ActiveRecord::AssociationRelation) }

    context 'when there are no denotations' do
      it { is_expected.to be_empty }
    end

    context 'when there are denotations' do
      let!(:denotation) { create(:denotation, doc: doc, project: project) }
      let!(:object_denotation) { create(:object_denotation, doc: doc, project: project) }
      let!(:verb_denotation) { create(:verb_denotation, doc: doc, project: project) }

      it { is_expected.not_to be_empty }

      it 'returns denotations' do
        expect(subject).to all(be_a(Denotation))
        expect(subject.second.hid).to eq('T2')
        expect(subject.third.hid).to eq('T3')
      end

      context 'with specified span' do
        let(:span) { {begin: 8, end: 14} }

        it 'returns denotations between the span' do
          expect(subject.first.hid).to eq('T2')
          expect(subject.second).to be_nil
        end
      end
    end
  end
end
