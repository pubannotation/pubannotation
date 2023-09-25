require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe 'get_blocks' do
    subject { project_doc.send(:get_blocks, span, context_size, sort) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }
    let(:context_size) { nil }
    let(:sort) { false }

    it { is_expected.to be_a(ActiveRecord::AssociationRelation) }

    context 'when there are no blocks' do
      it { is_expected.to be_empty }
    end

    context 'when there are blocks' do
      let!(:block) { create(:block, doc: doc, project: project) }
      let!(:third_block) { create(:third_block, doc: doc, project: project) }
      let!(:second_block) { create(:second_block, doc: doc, project: project) }

      it { is_expected.not_to be_empty }

      it 'returns blocks' do
        expect(subject).to all(be_a(Block))
        expect(subject.second.hid).to eq('B3')
        expect(subject.third.hid).to eq('B2')
      end

      context 'with specified span' do
        let(:span) { {begin: 10, end: 40} }

        it 'returns blocks within the span and adjusts by span and context_size' do
          adjusted_begin = 6 + (context_size || 0)
          adjusted_end = 27 + (context_size || 0)

          expect(subject.first.hid).to eq('B2')
          expect(subject.first.begin).to eq(adjusted_begin)
          expect(subject.first.end).to eq(adjusted_end)
        end

        context 'with specified context_size' do
          let(:context_size) { 6 }

          context 'equal to begin of the span' do
            let(:context_size) { 10 }

            it 'returns blocks without offset' do
              expect(subject.first.begin).to eq(16)
              expect(subject.first.end).to eq(37)
            end
          end

          context 'bigger than begin of the span' do
            let(:context_size) { 11 }

            it 'returns blocks without offset' do
              expect(subject.first.begin).to eq(16)
              expect(subject.first.end).to eq(37)
            end
          end
        end
      end

      context 'with sort specified' do
        let(:sort) { true }

        it 'returns blocks sorted by begin' do
          expect(subject.second.hid).to eq('B2')
          expect(subject.third.hid).to eq('B3')
        end
      end
    end
  end
end
