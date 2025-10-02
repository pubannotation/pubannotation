# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Annotation Workflow (End-to-End)', type: :model do
  describe 'complete annotation lifecycle' do
    let!(:project) { create(:project) }
    let!(:doc1) { create(:doc) }
    let!(:doc2) { create(:doc) }
    let!(:pd1) { create(:project_doc, project: project, doc: doc1) }
    let!(:pd2) { create(:project_doc, project: project, doc: doc2) }

    it 'maintains consistency through create → update → verify workflow' do
      # Step 1: Create annotations
      create_list(:denotation, 10, project: project, doc: doc1)
      create_list(:block, 5, project: project, doc: doc1)
      create_list(:denotation, 3, project: project, doc: doc2)

      # Step 2: Update counters
      Doc.update_numbers(project)

      # Step 3: Verify all tables are consistent
      doc1.reload
      expect(doc1.denotations_num).to eq(10)
      expect(doc1.blocks_num).to eq(5)

      pd1.reload
      expect(pd1.denotations_num).to eq(10)
      expect(pd1.blocks_num).to eq(5)

      doc2.reload
      expect(doc2.denotations_num).to eq(3)
      expect(doc2.blocks_num).to eq(0)

      pd2.reload
      expect(pd2.denotations_num).to eq(3)
      expect(pd2.blocks_num).to eq(0)

      project.reload
      project.clean
      expect(project.denotations_num).to eq(13)
      expect(project.blocks_num).to eq(5)
    end

    it 'maintains consistency through delete → update → verify workflow' do
      # Setup: Create and initialize
      create_list(:denotation, 10, project: project, doc: doc1)
      create_list(:block, 5, project: project, doc: doc1)
      Doc.update_numbers(project)

      doc1.reload
      expect(doc1.denotations_num).to eq(10)

      # Step 1: Delete some annotations
      Denotation.where(project: project, doc: doc1).limit(6).delete_all

      # Step 2: Update counters
      Doc.update_numbers(project)

      # Step 3: Verify consistency
      doc1.reload
      expect(doc1.denotations_num).to eq(4)

      pd1.reload
      expect(pd1.denotations_num).to eq(4)
    end

    it 'maintains consistency through complete deletion workflow' do
      # Setup
      create_list(:denotation, 10, project: project, doc: doc1)
      create_list(:block, 5, project: project, doc: doc1)
      Doc.update_numbers(project)

      # Step 1: Delete all annotations for project
      project.delete_annotations

      # Step 2: Verify all counters are zero
      doc1.reload
      expect(doc1.denotations_num).to eq(0)
      expect(doc1.blocks_num).to eq(0)

      pd1.reload
      expect(pd1.denotations_num).to eq(0)
      expect(pd1.blocks_num).to eq(0)

      project.reload
      expect(project.denotations_num).to eq(0)
      expect(project.blocks_num).to eq(0)
    end
  end

  describe 'multi-project workflows' do
    let!(:project1) { create(:project) }
    let!(:project2) { create(:project) }
    let!(:doc1) { create(:doc) }
    let!(:doc2) { create(:doc) }

    let!(:pd1_p1) { create(:project_doc, project: project1, doc: doc1) }
    let!(:pd2_p1) { create(:project_doc, project: project1, doc: doc2) }
    let!(:pd1_p2) { create(:project_doc, project: project2, doc: doc1) }

    it 'handles overlapping docs between projects correctly' do
      # Step 1: Create annotations in both projects for doc1
      create_list(:denotation, 5, project: project1, doc: doc1)
      create_list(:denotation, 7, project: project2, doc: doc1)
      create_list(:denotation, 3, project: project1, doc: doc2)

      # Step 2: Update counters for all
      Doc.update_numbers

      # Step 3: Verify doc1 has sum from both projects
      doc1.reload
      expect(doc1.denotations_num).to eq(12)
      expect(doc1.projects_num).to eq(2)

      # Step 4: Verify each project_doc has correct counts
      pd1_p1.reload
      expect(pd1_p1.denotations_num).to eq(5)

      pd1_p2.reload
      expect(pd1_p2.denotations_num).to eq(7)

      # Step 5: Delete from one project
      project1.delete_annotations

      # Step 6: Verify doc1 now only has project2's annotations
      doc1.reload
      expect(doc1.denotations_num).to eq(7)
      expect(doc1.projects_num).to eq(2)  # projects_num counts project_docs, not just those with annotations

      pd1_p1.reload
      expect(pd1_p1.denotations_num).to eq(0)

      pd1_p2.reload
      expect(pd1_p2.denotations_num).to eq(7)
    end
  end

  describe 'import workflows' do
    let!(:source_project) { create(:project) }
    let!(:target_project) { create(:project) }
    let!(:doc1) { create(:doc) }
    let!(:doc2) { create(:doc) }

    let!(:source_pd1) { create(:project_doc, project: source_project, doc: doc1) }
    let!(:source_pd2) { create(:project_doc, project: source_project, doc: doc2) }

    before do
      create_list(:denotation, 10, project: source_project, doc: doc1)
      create_list(:block, 5, project: source_project, doc: doc1)
      create_list(:denotation, 3, project: source_project, doc: doc2)

      Doc.update_numbers(source_project)
      source_project.clean
    end

    it 'skip import workflow: imports only to new docs' do
      # Setup target with one overlapping doc
      target_pd1 = create(:project_doc, project: target_project, doc: doc1, flag: true)

      # Step 1: Import with skip (only flagged)
      target_project.import_annotations_from_another_project_skip(source_project.id)

      # Step 2: Verify annotations were copied
      expect(Denotation.where(project: target_project, doc: doc1).count).to eq(10)
      expect(Block.where(project: target_project, doc: doc1).count).to eq(5)

      # Step 3: Verify counters are correct
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(10)
      expect(target_pd1.blocks_num).to eq(5)

      # Step 4: Verify doc has both projects' annotations
      doc1.reload
      expect(doc1.denotations_num).to eq(20)  # 10 from each project
      expect(doc1.blocks_num).to eq(10)       # 5 from each project
      expect(doc1.projects_num).to eq(2)

      # Step 5: Verify source unchanged
      source_project.reload
      expect(source_project.denotations_num).to eq(13)
    end

    it 'replace import workflow: replaces existing annotations' do
      # Setup target with existing annotations
      target_pd1 = create(:project_doc, project: target_project, doc: doc1, flag: true)
      create_list(:denotation, 20, project: target_project, doc: doc1)

      Doc.update_numbers(target_project)
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(20)

      # Step 1: Import with replace
      target_project.import_annotations_from_another_project_replace(source_project.id)

      # Step 2: Verify old annotations deleted, new ones added
      expect(Denotation.where(project: target_project, doc: doc1).count).to eq(10)

      # Step 3: Verify counters updated correctly
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(10)

      # Step 4: Verify project counts reflect net change
      target_project.reload
      expect(target_project.denotations_num).to eq(10)
    end
  end

  describe 'flagged docs workflows' do
    let!(:project) { create(:project) }
    let!(:doc1) { create(:doc) }
    let!(:doc2) { create(:doc) }
    let!(:doc3) { create(:doc) }

    let!(:pd1) { create(:project_doc, project: project, doc: doc1, flag: true) }
    let!(:pd2) { create(:project_doc, project: project, doc: doc2, flag: false) }
    let!(:pd3) { create(:project_doc, project: project, doc: doc3, flag: true) }

    it 'updates counts correctly and respects flagged filter' do
      # Create annotations in all docs
      create_list(:denotation, 5, project: project, doc: doc1)
      create_list(:denotation, 3, project: project, doc: doc2)
      create_list(:denotation, 7, project: project, doc: doc3)

      # Update all to get correct counts
      ProjectDoc.bulk_update_counts(project_id: project.id)

      pd1.reload
      expect(pd1.denotations_num).to eq(5)

      pd2.reload
      expect(pd2.denotations_num).to eq(3)

      pd3.reload
      expect(pd3.denotations_num).to eq(7)

      # flagged_only filter is tested in unit tests (spec/models/project_doc/bulk_update_counts_spec.rb)
    end
  end

  describe 'complex sequential operations' do
    let!(:project) { create(:project) }
    let!(:doc) { create(:doc) }
    let!(:pd) { create(:project_doc, project: project, doc: doc) }

    it 'maintains consistency through create → update → create → update → delete → update' do
      # Operation 1: Create some annotations
      create_list(:denotation, 5, project: project, doc: doc)
      Doc.update_numbers(project)

      doc.reload
      expect(doc.denotations_num).to eq(5)

      # Operation 2: Create more annotations
      create_list(:denotation, 3, project: project, doc: doc)
      Doc.update_numbers(project)

      doc.reload
      expect(doc.denotations_num).to eq(8)

      # Operation 3: Delete some
      Denotation.where(project: project, doc: doc).limit(4).delete_all
      Doc.update_numbers(project)

      doc.reload
      expect(doc.denotations_num).to eq(4)

      # Operation 4: Delete all
      project.delete_annotations

      doc.reload
      pd.reload
      project.reload
      expect(doc.denotations_num).to eq(0)
      expect(pd.denotations_num).to eq(0)
      expect(project.denotations_num).to eq(0)
    end
  end

  describe 'edge case workflows' do
    it 'handles empty project operations correctly' do
      project = create(:project)
      doc = create(:doc)
      pd = create(:project_doc, project: project, doc: doc)

      # Update counters with no annotations
      Doc.update_numbers(project)

      doc.reload
      pd.reload
      expect(doc.denotations_num).to eq(0)
      expect(pd.denotations_num).to eq(0)

      # Delete from empty project
      expect { project.delete_annotations }.not_to raise_error

      project.reload
      expect(project.denotations_num).to eq(0)
    end

    it 'handles project with docs but no project_docs correctly' do
      project = create(:project)
      doc = create(:doc)

      # Create annotations without project_doc (edge case)
      create_list(:denotation, 5, project: project, doc: doc)

      # This should handle gracefully
      Doc.update_numbers(project)

      doc.reload
      expect(doc.denotations_num).to eq(5)
    end
  end
end
