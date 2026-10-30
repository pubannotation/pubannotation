# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, 'annotation counts', type: :model do
  let(:project) { create(:project, denotations_num: 11, blocks_num: 12, relations_num: 13) }
  let(:doc) { create(:doc, body: '0123456789') }
  let!(:membership) { create(:project_doc, project: project, doc: doc, denotations_num: 2, blocks_num: 3, relations_num: 4) }

  it 'reads project totals or the persisted counters for a selected document' do
    expect([project.get_denotations_count, project.get_blocks_count, project.get_relations_count]).to eq([11, 12, 13])
    expect([project.get_denotations_count(doc), project.get_blocks_count(doc), project.get_relations_count(doc)]).to eq([2, 3, 4])
  end

  it 'returns nil for document counters when there is no membership' do
    other = create(:doc)
    expect([project.get_denotations_count(other), project.get_blocks_count(other), project.get_relations_count(other)]).to eq([nil, nil, nil])
  end

  it 'counts annotations within the span for the selected project and document' do
    denotation = create(:denotation, project: project, doc: doc, begin: 2, end: 4)
    other = create(:denotation, project: project, doc: doc, begin: 4, end: 6)
    create(:block, project: project, doc: doc, begin: 2, end: 4)
    create(:relation, project: project, doc: doc, subj: denotation, obj: other)
    create(:denotation, doc: doc, begin: 2, end: 4)

    expect([project.get_denotations_count(doc, { begin: 2, end: 6 }),
            project.get_blocks_count(doc, { begin: 2, end: 6 }),
            project.get_relations_count(doc, { begin: 2, end: 6 })]).to eq([2, 1, 1])
  end

  it 'counts matching annotations in a span even when membership is absent' do
    other = create(:doc, body: '0123456789')
    create(:denotation, project: project, doc: other, begin: 2, end: 4)

    expect(project.get_denotations_count(other, { begin: 0, end: 5 })).to eq(1)
  end
end
