# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, '.update_numbers (integration)', type: :model do
  let!(:project1) { create(:project) }
  let!(:project2) { create(:project) }

  let!(:doc1) { create(:doc) }
  let!(:doc2) { create(:doc) }
  let!(:doc3) { create(:doc) }

  let!(:pd1) { create(:project_doc, project: project1, doc: doc1) }
  let!(:pd2) { create(:project_doc, project: project1, doc: doc2) }
  let!(:pd3) { create(:project_doc, project: project2, doc: doc1) }
  let!(:pd4) { create(:project_doc, project: project2, doc: doc3) }

  before do
    # Project1 annotations
    create_list(:denotation, 5, project: project1, doc: doc1)
    create_list(:block, 3, project: project1, doc: doc1)

    create_list(:denotation, 2, project: project1, doc: doc2)

    # Project2 annotations
    create_list(:denotation, 7, project: project2, doc: doc1)
    create_list(:block, 1, project: project2, doc: doc1)

    create_list(:block, 4, project: project2, doc: doc3)
  end

  describe 'updating for a specific project' do
    it 'updates both docs and project_docs tables correctly' do
      Doc.update_numbers(project1)

      # Check project_docs for project1
      pd1.reload
      expect(pd1.denotations_num).to eq(5)
      expect(pd1.blocks_num).to eq(3)

      pd2.reload
      expect(pd2.denotations_num).to eq(2)
      expect(pd2.blocks_num).to eq(0)

      # Check docs table - should count across ALL projects
      doc1.reload
      expect(doc1.denotations_num).to eq(12)  # 5 from project1 + 7 from project2
      expect(doc1.blocks_num).to eq(4)        # 3 from project1 + 1 from project2
      expect(doc1.projects_num).to eq(2)

      doc2.reload
      expect(doc2.denotations_num).to eq(2)
      expect(doc2.blocks_num).to eq(0)
      expect(doc2.projects_num).to eq(1)
    end

    it 'only updates docs belonging to the specified project' do
      # Set wrong counts initially
      Doc.update_all(denotations_num: 999, blocks_num: 999, projects_num: 999)
      ProjectDoc.update_all(denotations_num: 999, blocks_num: 999)

      Doc.update_numbers(project1)

      # doc1 and doc2 belong to project1, should be updated
      doc1.reload
      expect(doc1.denotations_num).to eq(12)

      doc2.reload
      expect(doc2.denotations_num).to eq(2)

      # doc3 doesn't belong to project1, should remain unchanged
      doc3.reload
      expect(doc3.denotations_num).to eq(999)
    end
  end

  describe 'updating all docs' do
    it 'updates both docs and project_docs for all records' do
      Doc.update_numbers  # No project specified = update all

      # Check all project_docs
      pd1.reload
      expect(pd1.denotations_num).to eq(5)
      expect(pd1.blocks_num).to eq(3)

      pd2.reload
      expect(pd2.denotations_num).to eq(2)

      pd3.reload
      expect(pd3.denotations_num).to eq(7)
      expect(pd3.blocks_num).to eq(1)

      pd4.reload
      expect(pd4.denotations_num).to eq(0)
      expect(pd4.blocks_num).to eq(4)

      # Check all docs
      doc1.reload
      expect(doc1.denotations_num).to eq(12)
      expect(doc1.blocks_num).to eq(4)

      doc2.reload
      expect(doc2.denotations_num).to eq(2)

      doc3.reload
      expect(doc3.denotations_num).to eq(0)
      expect(doc3.blocks_num).to eq(4)
    end
  end

  describe 'consistency between docs and project_docs' do
    it 'ensures doc counts equal sum of project_doc counts' do
      Doc.update_numbers

      # Verify doc1 count = sum of its project_docs
      doc1.reload
      pd1.reload
      pd3.reload

      expect(doc1.denotations_num).to eq(pd1.denotations_num + pd3.denotations_num)
      expect(doc1.blocks_num).to eq(pd1.blocks_num + pd3.blocks_num)

      # Verify doc3 count = its single project_doc
      doc3.reload
      pd4.reload

      expect(doc3.denotations_num).to eq(pd4.denotations_num)
      expect(doc3.blocks_num).to eq(pd4.blocks_num)
    end
  end

  describe 'after annotation changes' do
    it 'reflects new annotations after update_numbers is called' do
      # Initial update
      Doc.update_numbers(project1)

      doc1.reload
      initial_count = doc1.denotations_num
      expect(initial_count).to eq(12)

      # Add more annotations
      create_list(:denotation, 10, project: project1, doc: doc1)

      # Update again
      Doc.update_numbers(project1)

      doc1.reload
      expect(doc1.denotations_num).to eq(22)  # 12 + 10

      pd1.reload
      expect(pd1.denotations_num).to eq(15)   # 5 + 10
    end

    it 'reflects deletions after update_numbers is called' do
      Doc.update_numbers(project1)

      # Delete some annotations
      Denotation.where(project: project1, doc: doc1).limit(3).delete_all

      Doc.update_numbers(project1)

      doc1.reload
      expect(doc1.denotations_num).to eq(9)  # 12 - 3

      pd1.reload
      expect(pd1.denotations_num).to eq(2)   # 5 - 3
    end
  end
end
