require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  describe '#bag_denotations' do
    subject { ProjectDoc.bag_denotations(denotations, relations) }

    let(:sample_denotations) do
      [
        {id: 'd1', span: {begin: 1, end: 5}, obj: 'o1'},
        {id: 'd2', span: {begin: 7, end: 9}, obj: 'o2'}
      ]
    end

    context 'when both denotations and relations are empty' do
      let(:denotations) { [] }
      let(:relations) { [] }

      it 'returns two empty arrays' do
        expect(subject).to all(be_a(Array))
      end
    end

    context 'when only denotations are given' do
      let(:denotations) { [sample_denotations.first] }
      let(:relations) { [] }

      it 'returns the given denotations and an empty relations array' do
        expect(subject).to eq([denotations, []])
      end
    end

    context 'when only relations are given' do
      let(:denotations) { [] }
      let(:relations) { [{id: 'r1', subj: 'd1', obj: 'd2', pred: 't1'}] }

      it 'returns an empty denotations array and the given relations' do
        expect(subject).to eq([[], relations])
      end
    end

    context 'when a denotation obj matches a relation obj with pred _lexicallyChainedTo' do
      let(:denotations) { sample_denotations }
      let(:relations) { [{id: 'r1', subj: 'd1', obj: 'd2', pred: '_lexicallyChainedTo'}] }

      it 'returns modified denotations and an empty relations array' do
        expect(subject).to eq([[{id: 'd1', span: [{begin: 7, end: 9}, {begin: 1, end: 5}], obj: 'o1'}], []])
      end
    end

    context 'when denotations are referenced by multiple relations' do
      let(:denotations) { sample_denotations }
      let(:relations) do
        [
          {id: 'r1', subj: 'd1', obj: 'd2', pred: '_lexicallyChainedTo'},
          {id: 'r2', subj: 'd2', obj: 'd1', pred: '_lexicallyChainedTo'}
        ]
      end

      it 'deletes denotations that have objs referenced by relations' do
        expect(subject).to eq([[], []])
      end
    end
  end
end
