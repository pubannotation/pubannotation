# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'serialization', type: :model do
  let(:doc) { build(:doc, sourcedb: 'PMC', sourceid: '123', body: '0123456789', source: 'https://example.org/source') }
  let(:routes) { Rails.application.routes.url_helpers }
  let(:target) { routes.doc_sourcedb_sourceid_show_url('PMC', '123', only_path: false) }

  it 'exports the document text and identity as hdoc' do
    expect(doc.hdoc).to eq(text: '0123456789', sourcedb: 'PMC', sourceid: '123')
  end

  it 'exports the full document including its source and text structures' do
    doc.divisions.build(begin: 1, end: 4, label: 'p')
    doc.typesettings.build(begin: 2, end: 3, style: 'bold')

    expect(doc.to_hash).to eq(
      target: target, sourcedb: 'PMC', sourceid: '123', source_url: 'https://example.org/source',
      text: '0123456789',
      divisions: [{ label: 'p', span: { begin: 1, end: 4 } }],
      typesettings: [{ style: 'bold', span: { begin: 2, end: 3 } }]
    )
  end

  it 'exports text and structures relative to the requested span and context' do
    doc.divisions.build(begin: 3, end: 5, label: 'p')
    doc.typesettings.build(begin: 4, end: 6, style: 'bold')

    expect(doc.to_hash({ begin: 3, end: 6 }, 1)).to include(
      text: '23456',
      divisions: [{ label: 'p', span: { begin: 1, end: 3 } }],
      typesettings: [{ style: 'bold', span: { begin: 2, end: 4 } }]
    )
  end

  it 'omits empty optional fields while retaining empty text' do
    doc.source = nil
    doc.body = ''

    expect(doc.to_hash).to eq(target: target, sourcedb: 'PMC', sourceid: '123', text: '')
  end

  it 'exports the document identity and URL for a list' do
    expect(doc.to_list_hash).to eq(
      sourcedb: 'PMC', sourceid: '123', url: routes.doc_sourcedb_sourceid_show_url('PMC', '123')
    )
  end

  it 'exports hash keys as TSV headers and quotes tabs, newlines, and quotes' do
    rows = [{ sourcedb: 'PMC', text: "a\tb\n\"c\"" }, { sourcedb: 'PubMed', text: 'plain' }]

    expect(Doc.hash_to_tsv(rows)).to eq("sourcedb\ttext\nPMC\t\"a\tb\n\"\"c\"\"\"\nPubMed\tplain\n")
  end

  it 'returns nil for an empty hash collection' do
    expect(Doc.hash_to_tsv([])).to be_nil
    expect(Doc.hash_to_tsv(nil)).to be_nil
  end

  it 'exports document list hashes as TSV' do
    other = build(:doc, sourcedb: 'PubMed', sourceid: '456')
    url = routes.doc_sourcedb_sourceid_show_url('PMC', '123')
    other_url = routes.doc_sourcedb_sourceid_show_url('PubMed', '456')

    expect(Doc.to_tsv([doc, other], nil)).to eq(
      "sourcedb\tsourceid\turl\nPMC\t123\t#{url}\nPubMed\t456\t#{other_url}\n"
    )
  end
end
