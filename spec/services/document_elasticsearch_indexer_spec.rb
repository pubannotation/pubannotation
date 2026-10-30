# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentElasticsearchIndexer do
  it 'indexes the document with its routing, identity, body and timestamps and refreshes the index' do
    created_at = Time.utc(2026, 1, 2, 3, 4, 5)
    updated_at = Time.utc(2026, 2, 3, 4, 5, 6)
    doc = build(:doc, id: 42, sourcedb: 'PMC', sourceid: '123', body: 'Example', created_at: created_at, updated_at: updated_at)
    result = { 'errors' => false }

    expect(ELASTICSEARCH_CLIENT).to receive(:bulk).with(
      body: [
        { index: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: '42', routing: '42' } },
        { doc_project_join: { name: 'doc' }, sourcedb: 'PMC', sourceid: '123', body: 'Example',
          created_at: created_at.iso8601, updated_at: updated_at.iso8601 }
      ], refresh: true
    ).and_return(result)

    expect(described_class.index!(doc)).to eq(result)
  end

  it 'passes nil timestamps through when they are absent' do
    doc = build(:doc, id: 42, created_at: nil, updated_at: nil)
    expect(ELASTICSEARCH_CLIENT).to receive(:bulk) do |body:, refresh:|
      expect(body.last).to include(created_at: nil, updated_at: nil)
      expect(refresh).to be true
    end

    described_class.index!(doc)
  end
end
