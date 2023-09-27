require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe 'get_blocks' do
    subject { project_doc.send(:get_blocks_in, span) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:project_doc) { create(:project_doc, doc: doc, project: project) }
    let(:span) { nil }

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

        it 'returns blocks within the span ' do
          expect(subject.first.hid).to eq('B2')
          expect(subject.second).to be_nil
        end
      end
    end
  end
end
