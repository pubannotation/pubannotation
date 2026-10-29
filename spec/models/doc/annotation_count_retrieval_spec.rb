# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'annotation count retrieval', type: :model do
  let(:doc) { create(:doc, denotations_num: 11, blocks_num: 12, relations_num: 13) }
  let(:project_doc) { create(:project_doc, doc: doc, denotations_num: 2, blocks_num: 3, relations_num: 4) }

  it 'reads document counters when neither project nor span is specified' do
    expect(doc.get_denotations_count).to eq(11)
    expect(doc.get_blocks_count).to eq(12)
    expect(doc.get_relations_count).to eq(13)
  end

  it 'reads the counters for the selected project and document' do
    project_id = project_doc.project_id
    expect(doc.get_denotations_count(project_id)).to eq(2)
    expect(doc.get_blocks_count(project_id)).to eq(3)
    expect(doc.get_relations_count(project_id)).to eq(4)
    expect(doc.project_relations_num(project_id)).to eq(4)
  end

  [:denotation, :block].each do |kind|
    it "counts #{kind}s in the span with an optional project filter" do
      project_id = project_doc.project_id
      create(kind, doc: doc, project_id: project_id, begin: 2, end: 5)
      create(kind, doc: doc, begin: 3, end: 6)
      create(kind, doc: doc, project_id: project_id, begin: 0, end: 8)
      method = kind == :denotation ? :get_denotations_count : :get_blocks_count

      expect(doc.public_send(method, nil, { begin: 2, end: 6 })).to eq(2)
      expect(doc.public_send(method, project_id, { begin: 2, end: 6 })).to eq(1)
    end
  end
end
