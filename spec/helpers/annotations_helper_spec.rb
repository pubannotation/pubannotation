require 'rails_helper'

RSpec.describe AnnotationsHelper, type: :helper do
  let(:project) { create(:project) }
  let(:doc) { create(:doc) }

  before do
    allow(helper).to receive(:current_user).and_return(nil)
    allow(project).to receive(:annotations_accessible?).and_return(true)
    project.update_columns(denotations_num: 1000, blocks_num: 2, relations_num: 3)
    doc.update_columns(denotations_num: 4, blocks_num: 5, relations_num: 6)
  end

  it 'reads current project and document counts from the database' do
    expect(helper.annotations_count_helper(project)).to eq(1005)
    expect(helper.annotations_count_detailed_helper(project)).to include('D1,000', 'B2', 'R3')
    expect(helper.annotations_count_helper(nil, doc)).to eq(15)
    expect(helper.annotations_count_detailed_helper(nil, doc)).to include('D4', 'B5', 'R6')
  end

  it 'reads counts for the project and document association' do
    ProjectDoc.create!(project: project, doc: doc, denotations_num: 7, blocks_num: 0, relations_num: 8)

    expect(helper.annotations_count_helper(project, doc)).to eq(15)
    expect(helper.annotations_count_detailed_helper(project, doc)).to include('D7', 'R8')
    expect(helper.annotations_count_detailed_helper(project, doc)).not_to include('Blocks')
  end

  it 'preserves the result for a missing association' do
    expect(helper.annotations_count_helper(project, doc)).to be_nil
    expect(helper.annotations_count_detailed_helper(project, doc)).to eq('0')
  end

  it 'hides counts when annotations are inaccessible' do
    allow(project).to receive(:annotations_accessible?).and_return(false)

    expect(helper.annotations_count_helper(project, doc)).to include('blinded')
    expect(helper.annotations_count_detailed_helper(project, doc)).to include('blinded')
  end

  it 'uses the only project for a document when none is supplied' do
    ProjectDoc.create!(project: project, doc: doc, denotations_num: 7)
    doc.update_columns(projects_num: 1)
    allow_any_instance_of(Project).to receive(:annotations_accessible?).and_return(true)

    expect(helper.annotations_count_helper(nil, doc)).to eq(7)
    expect(helper.annotations_count_detailed_helper(nil, doc)).to include('D7')
  end
end
