# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, '#delete_annotations (integration)', type: :model do
  let!(:project) { create(:project) }
  let!(:other_project) { create(:project) }

  let!(:doc1) { create(:doc) }
  let!(:doc2) { create(:doc) }
  let!(:doc3) { create(:doc) }

  let!(:pd1) { create(:project_doc, project: project, doc: doc1) }
  let!(:pd2) { create(:project_doc, project: project, doc: doc2) }
  let!(:pd3) { create(:project_doc, project: other_project, doc: doc1) }
  let!(:pd4) { create(:project_doc, project: other_project, doc: doc3) }

  before do
    # Project annotations
    create_list(:denotation, 10, project: project, doc: doc1)
    create_list(:block, 5, project: project, doc: doc1)

    create_list(:denotation, 3, project: project, doc: doc2)
    create_list(:block, 2, project: project, doc: doc2)

    # Other project annotations (should NOT be deleted)
    create_list(:denotation, 7, project: other_project, doc: doc1)
    create_list(:block, 4, project: other_project, doc: doc3)

    # Initialize counters
    Doc.update_numbers
    ProjectDoc.bulk_update_counts
  end

  describe 'deleting all annotations from a project' do
    it 'removes all annotations for that project only' do
      expect {
        project.delete_annotations
      }.to change { Denotation.where(project: project).count }.from(13).to(0)
        .and change { Block.where(project: project).count }.from(7).to(0)

      # Other project's annotations should remain
      expect(Denotation.where(project: other_project).count).to eq(7)
      expect(Block.where(project: other_project).count).to eq(4)
    end

    it 'updates project_docs counts to zero for this project' do
      project.delete_annotations

      pd1.reload
      expect(pd1.denotations_num).to eq(0)
      expect(pd1.blocks_num).to eq(0)

      pd2.reload
      expect(pd2.denotations_num).to eq(0)
      expect(pd2.blocks_num).to eq(0)

      # Other project's project_docs should be unchanged
      pd3.reload
      expect(pd3.denotations_num).to eq(7)

      pd4.reload
      expect(pd4.blocks_num).to eq(4)
    end

    it 'updates docs counts to reflect only remaining annotations' do
      project.delete_annotations

      # doc1 had annotations from both projects
      # After deleting project's annotations, should only have other_project's
      doc1.reload
      expect(doc1.denotations_num).to eq(7)   # Only from other_project
      expect(doc1.blocks_num).to eq(0)        # project had 5, other_project had 0

      # doc2 only had annotations from project
      # After deletion, should be zero
      doc2.reload
      expect(doc2.denotations_num).to eq(0)
      expect(doc2.blocks_num).to eq(0)

      # doc3 only has annotations from other_project (unchanged)
      doc3.reload
      expect(doc3.denotations_num).to eq(0)
      expect(doc3.blocks_num).to eq(4)
    end

    it 'updates project counts to zero' do
      project.reload
      initial_denotations = project.denotations_num

      project.delete_annotations

      project.reload
      expect(project.denotations_num).to eq(0)
      expect(project.blocks_num).to eq(0)
      expect(project.relations_num).to eq(0)
    end

    it 'maintains cross-table consistency after deletion' do
      project.delete_annotations

      # Verify doc1 count equals sum of its project_docs
      doc1.reload
      pd1.reload
      pd3.reload

      expect(doc1.denotations_num).to eq(pd1.denotations_num + pd3.denotations_num)
      expect(doc1.blocks_num).to eq(pd1.blocks_num + pd3.blocks_num)

      # Verify doc2 count equals its single project_doc (now zero)
      doc2.reload
      pd2.reload

      expect(doc2.denotations_num).to eq(pd2.denotations_num)
      expect(doc2.blocks_num).to eq(pd2.blocks_num)
    end
  end

  describe 'deleting when project has no annotations' do
    it 'handles gracefully without errors' do
      # Create empty project
      empty_project = create(:project)
      create(:project_doc, project: empty_project, doc: doc1)

      expect {
        empty_project.delete_annotations
      }.not_to raise_error
    end
  end

  describe 'deleting multiple times' do
    it 'is idempotent - can be called multiple times safely' do
      project.delete_annotations

      # Call again - should not raise error
      expect {
        project.delete_annotations
      }.not_to raise_error

      # Counts should still be zero
      project.reload
      expect(project.denotations_num).to eq(0)
    end
  end

  describe 'isolation between projects' do
    it 'deleting from one project does not affect another project' do
      # Record initial state of other_project
      other_project.reload
      initial_other_denotations = Denotation.where(project: other_project).count

      # Delete from project
      project.delete_annotations

      # Verify other_project unchanged
      expect(Denotation.where(project: other_project).count).to eq(initial_other_denotations)

      other_project.reload
      # Note: other_project's counts won't be updated by project.delete_annotations
      # They would need other_project.reload or Doc.update_numbers to be called
    end
  end
end
