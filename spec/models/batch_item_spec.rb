# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BatchItem, type: :model do
  describe '#new' do
    subject { described_class.new }

    it 'creates an instance' do
      expect(subject).to be_a(described_class)
    end
  end

  describe '#<<' do
    subject(:batch_item) { described_class.new }

    context 'when adding multiple annotation collections' do
      before do
        batch_item << create_annotation_collection('PubMed', '001', 'text')
        batch_item << create_annotation_collection('PubMed', '002', 'text')
        batch_item << create_annotation_collection('PMC', 'A01', 'text')
      end

      it 'adds an annotation collection to the transaction' do
        expect(batch_item.annotation_transaction.length).to eq(3)
      end

      it 'adds a sourcedb and sourceid to the index' do
        expect(batch_item.sourcedb_sourceids_index).to eq({
                                                            'PubMed' => %w[001 002],
                                                            'PMC' => ['A01']
                                                          })
      end
    end
  end

  # Helper method to DRY up the code
  def create_annotation_collection(sourcedb, sourceid, text)
    AnnotationCollection.new([
                               { sourcedb: sourcedb, sourceid: sourceid, text: text }
                             ].to_json)
  end
end
