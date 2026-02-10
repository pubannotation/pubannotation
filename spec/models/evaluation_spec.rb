# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evaluation, type: :model do
  describe '#false_negatives' do
    let(:evaluation) { Evaluation.new }

    let(:fn_entries) do
      5.times.map do |i|
        {
          type: 'denotation',
          sourcedb: 'PubMed',
          sourceid: i.to_s,
          reference: { obj: 'Species', text: "species_#{i}", span: { begin: 0, end: 10 } }
        }
      end
    end

    before do
      allow(evaluation).to receive(:hresult).and_return({ false_negatives: fn_entries })
    end

    it 'returns entries for the first page' do
      result = evaluation.false_negatives('denotation', 'Species', :text, 1, 10)
      expect(result).to be_an(Array)
      expect(result.length).to eq(5)
    end

    it 'returns an empty array when page offset exceeds results' do
      result = evaluation.false_negatives('denotation', 'Species', :text, 2, 10)
      expect(result).to eq([])
    end

    it 'returns an empty array for a far-out page' do
      result = evaluation.false_negatives('denotation', 'Species', :text, 100, 10)
      expect(result).to eq([])
    end
  end
end
