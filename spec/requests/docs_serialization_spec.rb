# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document serialization', type: :request do
  let!(:doc) { create(:doc, sourcedb: 'PMC', sourceid: '123', body: '0123456789') }

  it 'exports document identities as JSON' do
    get '/docs.json', params: { sourcedb: 'PMC' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to contain_exactly(
      'sourcedb' => 'PMC', 'sourceid' => '123',
      'url' => Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url('PMC', '123')
    )
  end

  it 'exports document identities as TSV' do
    get '/docs.tsv', params: { sourcedb: 'PMC' }

    expect(response).to have_http_status(:ok)
    expect(CSV.parse(response.body, col_sep: "\t", headers: true).map(&:to_h)).to eq([
      { 'sourcedb' => 'PMC', 'sourceid' => '123',
        'url' => Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url('PMC', '123') }
    ])
  end

  it 'exports a document span as JSON' do
    get '/docs/sourcedb/PMC/sourceid/123/spans/3-6.json'

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('sourcedb' => 'PMC', 'sourceid' => '123', 'text' => '345')
  end

  it 'exports annotation tracks with text relative to the requested context' do
    project = create(:project)
    create(:project_doc, project: project, doc: doc)
    denotation = create(:denotation, project: project, doc: doc, begin: 3, end: 5)

    get '/docs/sourcedb/PMC/sourceid/123/spans/3-6/annotations.json', params: { context_size: 1 }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'text' => '23456',
      'tracks' => [include(
        'project' => project.name,
        'denotations' => [include('id' => denotation.hid, 'span' => { 'begin' => 1, 'end' => 3 })]
      )]
    )
  end
end
