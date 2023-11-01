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
    subject { batch_item << annotation_collection }

    let(:batch_item) { described_class.new }
    let(:annotation_collection) { [] }

    it 'adds an annotation collection to the transaction' do
      expect { subject }.to change { batch_item.annotation_transaction.length }.by(1)
    end

    it 'adds a sourcedb and sourceid to the index' do
      expect { subject }.to change { batch_item.sourcedb_sourceids_index[annotation_collection.sourcedb].include?(annotation_collection.sourceid) }.from(false).to(true)
    end
  end
end
