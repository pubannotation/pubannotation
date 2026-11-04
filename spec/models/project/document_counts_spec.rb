require 'rails_helper'

RSpec.describe Project do
  let(:project) { create(:project) }
  let(:doc) { create(:doc, sourcedb: 'Example') }

  before { allow(Project).to receive(:admin_project).and_return(nil) }

  it 'increments counts on addition and decrements them on removal from the project' do
    project.add_doc!(doc)
    expect(project.reload.docs_count).to eq(1)
    expect(project.docs_stat['Example']).to eq(1)

    project.delete_doc(doc)
    expect(project.reload.docs_count).to eq(0)
    expect(project.docs_stat['Example']).to eq(0)
    expect(Doc.exists?(doc.id)).to be(true)
  end

  it 'decrements counts for every project when the document itself is destroyed' do
    other_project = create(:project)
    project.add_doc!(doc)
    other_project.add_doc!(doc)
    doc.destroy!

    [project, other_project].each do |p|
      expect(p.reload.docs_count).to eq(0)
      expect(p.docs_stat['Example']).to eq(0)
    end
  end

  it 'rolls back project counts when document deletion rolls back' do
    project.add_doc!(doc)
    Doc.transaction do
      doc.destroy!
      raise ActiveRecord::Rollback
    end

    expect(project.reload.docs_count).to eq(1)
    expect(project.docs_stat['Example']).to eq(1)
    expect(project.docs).to include(doc)
  end
end
