# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project, '#update_numbers_for_flagged_docs (integration)', type: :model do
  let!(:source_project) { create(:project) }
  let!(:target_project) { create(:project) }

  let!(:doc1) { create(:doc) }
  let!(:doc2) { create(:doc) }
  let!(:doc3) { create(:doc) }

  # Source project has annotations on all docs
  let!(:source_pd1) { create(:project_doc, project: source_project, doc: doc1) }
  let!(:source_pd2) { create(:project_doc, project: source_project, doc: doc2) }
  let!(:source_pd3) { create(:project_doc, project: source_project, doc: doc3) }

  # Target project has some docs, some will be flagged
  let!(:target_pd1) { create(:project_doc, project: target_project, doc: doc1, flag: true) }
  let!(:target_pd2) { create(:project_doc, project: target_project, doc: doc2, flag: false) }
  let!(:target_pd3) { create(:project_doc, project: target_project, doc: doc3, flag: true) }

  before do
    # Source project annotations
    create_list(:denotation, 5, project: source_project, doc: doc1)
    create_list(:block, 3, project: source_project, doc: doc1)

    create_list(:denotation, 7, project: source_project, doc: doc2)
    create_list(:block, 2, project: source_project, doc: doc2)

    create_list(:denotation, 4, project: source_project, doc: doc3)
    create_list(:block, 1, project: source_project, doc: doc3)

    # Target project already has some annotations (will be replaced)
    create_list(:denotation, 2, project: target_project, doc: doc1)
    create_list(:denotation, 3, project: target_project, doc: doc2)

    # Initialize all counters
    Doc.update_numbers
    ProjectDoc.bulk_update_counts
    source_project.clean
    target_project.clean
  end

  describe 'importing with skip strategy (only flagged docs)' do
    it 'updates counters only for flagged project_docs' do
      target_project.import_annotations_from_another_project_skip(source_project.id)

      # Flagged project_docs should be updated
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(7)  # 2 existing + 5 imported
      expect(target_pd1.blocks_num).to eq(3)       # 0 existing + 3 imported

      target_pd3.reload
      expect(target_pd3.denotations_num).to eq(4)  # 0 existing + 4 imported
      expect(target_pd3.blocks_num).to eq(1)       # 0 existing + 1 imported

      # Non-flagged project_doc should remain at original count
      target_pd2.reload
      expect(target_pd2.denotations_num).to eq(3)  # Original count unchanged
      expect(target_pd2.blocks_num).to eq(0)
    end

    it 'updates doc counters to reflect all projects annotations' do
      target_project.import_annotations_from_another_project_skip(source_project.id)

      # doc1 has annotations from both projects
      doc1.reload
      expect(doc1.denotations_num).to eq(12)  # 5 (source) + 7 (target: 2 + 5 imported)
      expect(doc1.blocks_num).to eq(6)        # 3 (source) + 3 (target: 0 + 3 imported)

      # doc2 has annotations from both projects (but target's weren't updated because not flagged)
      doc2.reload
      expect(doc2.denotations_num).to eq(10)  # 7 (source) + 3 (target, unchanged)
      expect(doc2.blocks_num).to eq(2)        # 2 (source) + 0 (target)

      # doc3 now has annotations from both projects
      doc3.reload
      expect(doc3.denotations_num).to eq(8)   # 4 (source) + 4 (target: 0 + 4 imported)
      expect(doc3.blocks_num).to eq(2)        # 1 (source) + 1 (target: 0 + 1 imported)
    end

    it 'updates project counters correctly' do
      target_project.reload
      initial_denotations = target_project.denotations_num
      initial_blocks = target_project.blocks_num

      target_project.import_annotations_from_another_project_skip(source_project.id)

      target_project.reload
      # Should add: 5 (doc1) + 4 (doc3) = 9 denotations
      expect(target_project.denotations_num).to eq(initial_denotations + 9)
      # Should add: 3 (doc1) + 1 (doc3) = 4 blocks
      expect(target_project.blocks_num).to eq(initial_blocks + 4)
    end

    it 'updates annotations_updated_at timestamp for flagged project_docs only' do
      # Clear timestamps
      ProjectDoc.update_all(annotations_updated_at: nil)

      travel_to Time.current do
        target_project.import_annotations_from_another_project_skip(source_project.id)

        # Flagged should have timestamp
        target_pd1.reload
        expect(target_pd1.annotations_updated_at).to be_within(1.second).of(Time.current)

        target_pd3.reload
        expect(target_pd3.annotations_updated_at).to be_within(1.second).of(Time.current)

        # Non-flagged should still be nil
        target_pd2.reload
        expect(target_pd2.annotations_updated_at).to be_nil
      end
    end
  end

  describe 'importing with replace strategy (flagged docs)' do
    it 'replaces annotations in flagged docs and updates counters correctly' do
      target_project.import_annotations_from_another_project_replace(source_project.id)

      # All duplicate docs get flagged and replaced (doc1, doc2 exist in both projects)
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(5)  # Replaced with source count
      expect(target_pd1.blocks_num).to eq(3)

      target_pd2.reload
      expect(target_pd2.denotations_num).to eq(7)  # doc2 was flagged and replaced
      expect(target_pd2.blocks_num).to eq(2)

      target_pd3.reload
      expect(target_pd3.denotations_num).to eq(4)  # Replaced with source count
      expect(target_pd3.blocks_num).to eq(1)
    end

    it 'updates project counters with net change (deleted + added)' do
      target_project.reload
      initial_denotations = target_project.denotations_num

      target_project.import_annotations_from_another_project_replace(source_project.id)

      target_project.reload
      # Net change: -2 (deleted from doc1) - 3 (deleted from doc2) + 5 (added doc1) + 7 (added doc2) + 4 (added doc3) = +11
      expect(target_project.denotations_num).to eq(initial_denotations + 11)
    end
  end

  describe 'importing with add strategy (flagged docs)' do
    it 'adds to existing annotations in flagged docs' do
      target_project.import_annotations_from_another_project_add(source_project.id)

      # Flagged project_docs should have existing + imported
      target_pd1.reload
      expect(target_pd1.denotations_num).to eq(7)  # 2 existing + 5 imported
      expect(target_pd1.blocks_num).to eq(3)       # 0 existing + 3 imported

      target_pd3.reload
      expect(target_pd3.denotations_num).to eq(4)  # 0 existing + 4 imported
      expect(target_pd3.blocks_num).to eq(1)       # 0 existing + 1 imported
    end
  end

  describe 'cross-table consistency after flagged update' do
    it 'ensures doc counts equal sum of project_doc counts' do
      target_project.import_annotations_from_another_project_skip(source_project.id)

      # Verify doc1 count = sum of its project_docs
      doc1.reload
      source_pd1.reload
      target_pd1.reload

      expect(doc1.denotations_num).to eq(source_pd1.denotations_num + target_pd1.denotations_num)
      expect(doc1.blocks_num).to eq(source_pd1.blocks_num + target_pd1.blocks_num)

      # Verify doc3 count = sum of its project_docs
      doc3.reload
      source_pd3.reload
      target_pd3.reload

      expect(doc3.denotations_num).to eq(source_pd3.denotations_num + target_pd3.denotations_num)
      expect(doc3.blocks_num).to eq(source_pd3.blocks_num + target_pd3.blocks_num)
    end
  end

  describe 'flag management' do
    it 'clears flags after import' do
      expect(target_pd1.flag).to eq(true)
      expect(target_pd3.flag).to eq(true)

      target_project.import_annotations_from_another_project_skip(source_project.id)

      target_pd1.reload
      target_pd3.reload

      expect(target_pd1.flag).to eq(false)
      expect(target_pd3.flag).to eq(false)
    end
  end

  describe 'isolation - source project unchanged' do
    it 'does not modify source project or its counts' do
      source_project.reload
      initial_source_denotations = source_project.denotations_num

      target_project.import_annotations_from_another_project_skip(source_project.id)

      # Source project should be completely unchanged
      source_project.reload
      expect(source_project.denotations_num).to eq(initial_source_denotations)

      source_pd1.reload
      expect(source_pd1.denotations_num).to eq(5)
    end
  end
end
