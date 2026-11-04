require 'rails_helper'

RSpec.describe Doc do
  let(:admin_project) { create(:project, docs_count: 2, docs_stat: { 'Example' => 2 }) }

  before { allow(Project).to receive(:admin_project).and_return(admin_project) }

  it 'decrements global counts when a document is destroyed' do
    doc = create(:doc, sourcedb: 'Example')
    doc.destroy!

    expect(admin_project.reload.docs_count).to eq(1)
    expect(admin_project.docs_stat['Example']).to eq(1)
  end

  it 'rolls back global counts if the deletion is rolled back' do
    doc = create(:doc, sourcedb: 'Example')
    Doc.transaction do
      doc.destroy!
      raise ActiveRecord::Rollback
    end

    expect(doc.class.exists?(doc.id)).to be(true)
    expect(admin_project.reload.docs_count).to eq(2)
    expect(admin_project.docs_stat['Example']).to eq(2)
  end
end
