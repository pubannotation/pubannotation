require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe 'get_denotations' do
    subject { project_doc.send(:get_denotations, span, context_size) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }
    let(:context_size) { nil }

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

        it 'returns denotations between the span and adjusts by span and context_size' do
          adjusted_begin = object_denotation.begin - span[:begin] + (context_size || 0)
          adjusted_end = object_denotation.end - span[:begin] + (context_size || 0)

          expect(subject.first.hid).to eq(object_denotation.hid)
          expect(subject.first.begin).to eq(adjusted_begin)
          expect(subject.first.end).to eq(adjusted_end)
        end

        context 'with specified context_size' do
          let(:context_size) { 6 }

          context 'equal to begin of the span' do
            let(:context_size) { 8 }

            it 'returns denotations without offset' do
              expect(subject.first.begin).to eq(object_denotation.begin)
              expect(subject.first.end).to eq(object_denotation.end)
            end
          end

          context 'bigger than begin of the span' do
            let(:context_size) { 10 }

            it 'returns denotations without offset' do
              expect(subject.first.begin).to eq(object_denotation.begin)
              expect(subject.first.end).to eq(object_denotation.end)
            end
          end
        end
      end
    end
  end
end
