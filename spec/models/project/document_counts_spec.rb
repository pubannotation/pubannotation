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

  it 'counts documents added by batch processing only once' do
    doc
    specs = [{ sourcedb: doc.sourcedb, sourceid: doc.sourceid }]

    project.add_docs_from_array(specs, batch_processing: true)
    project.add_docs_from_array(specs, batch_processing: true)

    expect(project.reload.docs_count).to eq(1)
    expect(project.docs_stat['Example']).to eq(1)
    expect(project.docs).to contain_exactly(doc)
  end

  it 'rolls back batch membership when updating its counts fails' do
    doc
    allow(project).to receive(:docs_stat_increment!).and_raise('count failed')

    expect { project.add_docs_from_array([{ sourcedb: doc.sourcedb, sourceid: doc.sourceid }], batch_processing: true) }
      .to raise_error('count failed')
    expect(project.reload.docs_count).to eq(0)
    expect(project.docs).to be_empty
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
