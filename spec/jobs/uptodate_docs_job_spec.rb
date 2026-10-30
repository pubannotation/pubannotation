# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UptodateDocsJob, type: :job do
  it 'fetches a batch once and revises each document from the returned text' do
    project = create(:project)
    first = create(:doc, sourcedb: 'PMC', sourceid: '123', body: 'Hello world')
    second = create(:doc, sourcedb: 'PMC', sourceid: '456', body: 'Other text')
    create(:project_doc, project: project, doc: first)
    create(:project_doc, project: project, doc: second)
    denotation = create(:denotation, project: project, doc: first, begin: 6, end: 11)
    hdocs = [
      { sourcedb: 'PMC', sourceid: '123', text: 'Hello big world' },
      { sourcedb: 'PMC', sourceid: '456', text: 'New text' }
    ]
    expect(DocumentFetcher).to receive(:fetch).with('PMC', match_array(%w[123 456])).once.and_return([hdocs, []])

    described_class.perform_now(project)

    expect(first.reload.body).to eq('Hello big world')
    expect(second.reload.body).to eq('New text')
    expect([denotation.reload.begin, denotation.end]).to eq([10, 15])
  end
end
