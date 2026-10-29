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

  describe '#hannotations' do
    let(:doc) { super().tap(&:save!) }
    let(:project) { create(:project) }
    let(:other_project) { create(:project) }
    let!(:denotation) { create(:denotation, doc: doc, project: project, begin: 3, end: 5) }
    let!(:other_denotation) { create(:denotation, doc: doc, project: other_project, begin: 6, end: 8) }

    before do
      create(:project_doc, doc: doc, project: project)
      create(:project_doc, doc: doc, project: other_project)
    end

    it 'merges a single project annotations into the document without tracks' do
      hash = doc.hannotations(project, nil, nil)

      expect(hash).to include(text: doc.body, target: target, project: project.name, denotations: [denotation.as_json])
      expect(hash).not_to have_key(:tracks)
    end

    it 'exports only the selected projects as tracks when given a collection' do
      hash = doc.hannotations([project], nil, nil)

      expect(hash).to include(text: doc.body, target: target)
      expect(hash[:tracks]).to contain_exactly(include(project: project.name, denotations: [denotation.as_json]))
      expect(hash).not_to have_key(:denotations)
    end

    it 'exports all project tracks when no project is specified' do
      hash = doc.hannotations(nil, nil, nil)

      expect(hash[:tracks]).to contain_exactly(
        include(project: project.name, denotations: [denotation.as_json]),
        include(project: other_project.name, denotations: [other_denotation.as_json])
      )
    end

    it 'exports text and annotation offsets relative to the span and context' do
      hash = doc.hannotations(project, { begin: 3, end: 6 }, 1, is_sort: true)

      expect(hash).to include(
        text: '23456',
        denotations: [{ id: denotation.hid, obj: denotation.obj, span: { begin: 1, end: 3 } }]
      )
    end

    it 'retains empty project tracks only when full output is requested' do
      empty_project = create(:project)
      create(:project_doc, doc: doc, project: empty_project)

      expect(doc.hannotations([empty_project], nil, nil)[:tracks]).to eq([])
      expect(doc.hannotations([empty_project], nil, nil, is_full: true)[:tracks]).to contain_exactly(include(project: empty_project.name))
    end
  end
end
