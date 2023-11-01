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
    let(:batch_item) { described_class.new }

    before do
      batch_item << AnnotationCollection.new([
                                               { sourcedb: 'PubMed', sourceid: '001', text: 'text' },
                                               { sourcedb: 'PubMed', sourceid: '001', text: 'text' },
                                             ].to_json)

      batch_item << AnnotationCollection.new([
                                               { sourcedb: 'PubMed', sourceid: '002', text: 'text' },
                                             ].to_json)

      batch_item << AnnotationCollection.new([
                                               { sourcedb: 'PMC', sourceid: 'A01', text: 'text' },
                                             ].to_json)
    end

    it 'adds an annotation collection to the transaction' do
      expect(batch_item.annotation_transaction.length).to eq(3)
    end

    it 'adds a sourcedb and sourceid to the index' do
      expect(batch_item.sourcedb_sourceids_index).to eq({
                                                          'PubMed' => Set.new(%w[001 002 A01]),
                                                          'PMC' => Set.new(%w[001 002 A01]),
                                                        })
    end
  end
end
