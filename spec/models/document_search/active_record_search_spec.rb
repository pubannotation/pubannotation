# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentSearch, 'Active Record search', type: :model do
  let(:project) { create(:project) }
  let!(:first) { create(:doc, sourcedb: 'PMC', sourceid: '1') }
  let!(:second) { create(:doc, sourcedb: 'PMC', sourceid: '2') }

  before do
    create(:project_doc, project: project, doc: first)
    create(:project_doc, project: project, doc: second)
  end

  it 'filters by project and source database before sorting and paginating' do
    create(:doc, sourcedb: 'PMC', sourceid: '3')
    create(:project_doc, project: project, doc: create(:doc, sourcedb: 'Other'))

    expect(DocumentSearch.search_by_active_record(2, 1, project, 'PMC', 'sourceid', 'DESC').to_a).to eq([first])
  end

  it 'keeps the default sort helper public and sorts small projects by source ID' do
    expect(DocumentSearch.default_sort_order_for(project)).to eq('sourceid ASC')
    expect(DocumentSearch.default_sort_order_for(nil)).to eq('')
    expect(DocumentSearch.search_by_active_record(1, 10, project).to_a).to eq([first, second])
  end

  it 'supports randomized ordering without an explicit sort' do
    expect(DocumentSearch.search_by_active_record(1, 10, nil, 'PMC', nil, nil, true).to_a).to match_array([first, second])
  end

  it 'exports paginated document identities for an accessible base project without terms' do
    expect(DocumentSearch.search_by_term(project.user, project.name, nil, nil, nil, 1, 10)).to match_array(
      [first.to_list_hash, second.to_list_hash]
    )
  end
end
