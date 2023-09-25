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

    it 'returns an array' do
      is_expected.to be_a(ActiveRecord::AssociationRelation)
    end

    context 'when there are no blocks' do
      it { is_expected.to be_empty }
    end

    context 'when there are blocks' do
      before do
        create(:block, doc: doc, project: project)
        create(:third_block, doc: doc, project: project)
        create(:second_block, doc: doc, project: project)
      end

      it { is_expected.not_to be_empty }

      it 'returns an array of blocks' do
        expect(subject.first).to be_a(Block)
      end

      it 'return an array of blocks sorted by creation order' do
        expect(subject.second.hid).to eq('B3')
        expect(subject.third.hid).to eq('B2')
      end

      context 'when span is specified' do
        let(:span) { {begin: 10, end: 40} }

        it 'returns an array of blocks between the specified span' do
          expect(subject.first.hid).to eq('B2')
        end

        it 'returns an array of blocks offset by the specified span' do
          expect(subject.first.begin).to eq(6)
          expect(subject.first.end).to eq(27)
        end

        context 'when context_size is specified' do
          let(:context_size) { 6 }

          it 'returns an array of blocks offset by the specified span and context_size' do
            expect(subject.first.begin).to eq(6 + context_size)
            expect(subject.first.end).to eq(27 + context_size)
          end

          context 'when context_size equals to begin of the span' do
            let(:context_size) { 10 }

            it 'returns an array of blocks without offset' do
              expect(subject.first.begin).to eq(16)
              expect(subject.first.end).to eq(37)
            end
          end

          context 'when context_size is bigger than begin of the span' do
            let(:context_size) { 11 }

            it 'returns an array of blocks without offset' do
              expect(subject.first.begin).to eq(16)
              expect(subject.first.end).to eq(37)
            end
          end
        end
      end

      context 'when sort is specified' do
        let(:sort) { true }

        it 'return an array of blocks sorted by begin' do
          expect(subject.second.hid).to eq('B2')
          expect(subject.third.hid).to eq('B3')
        end
      end
    end
  end
end
