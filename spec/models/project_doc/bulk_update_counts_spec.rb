# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectDoc, '.bulk_update_counts', type: :model do
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
    create_list(:denotation, 3, project: project1, doc: doc1)
    create_list(:block, 2, project: project1, doc: doc1)

    create_list(:denotation, 5, project: project1, doc: doc2)
    create_list(:block, 1, project: project1, doc: doc2)

    # Project2 annotations
    create_list(:denotation, 7, project: project2, doc: doc1)

    # pd4 (project2 + doc3) has no annotations
  end

  describe 'updating all project_docs' do
    it 'updates counts for all project_docs' do
      ProjectDoc.bulk_update_counts

      pd1.reload
      expect(pd1.denotations_num).to eq(3)
      expect(pd1.blocks_num).to eq(2)

      pd2.reload
      expect(pd2.denotations_num).to eq(5)
      expect(pd2.blocks_num).to eq(1)

      pd3.reload
      expect(pd3.denotations_num).to eq(7)
      expect(pd3.blocks_num).to eq(0)

      pd4.reload
      expect(pd4.denotations_num).to eq(0)
      expect(pd4.blocks_num).to eq(0)
    end
  end

  describe 'filtering by project_id' do
    it 'updates only project_docs for specified project' do
      # Set wrong counts
      pd1.update_columns(denotations_num: 999, blocks_num: 999)
      pd2.update_columns(denotations_num: 999, blocks_num: 999)
      pd3.update_columns(denotations_num: 999, blocks_num: 999)
      pd4.update_columns(denotations_num: 999, blocks_num: 999)

      # Update only project1's project_docs
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      pd1.reload
      expect(pd1.denotations_num).to eq(3)
      expect(pd1.blocks_num).to eq(2)

      pd2.reload
      expect(pd2.denotations_num).to eq(5)
      expect(pd2.blocks_num).to eq(1)

      # project2's project_docs should remain unchanged
      pd3.reload
      expect(pd3.denotations_num).to eq(999)

      pd4.reload
      expect(pd4.denotations_num).to eq(999)
    end
  end

  describe 'filtering by doc_ids' do
    it 'updates only project_docs for specified docs' do
      # Set wrong counts
      ProjectDoc.update_all(denotations_num: 999, blocks_num: 999)

      # Update only doc1's project_docs
      ProjectDoc.bulk_update_counts(doc_ids: [doc1.id])

      pd1.reload
      expect(pd1.denotations_num).to eq(3)

      pd3.reload
      expect(pd3.denotations_num).to eq(7)

      # doc2 and doc3 project_docs should remain unchanged
      pd2.reload
      expect(pd2.denotations_num).to eq(999)

      pd4.reload
      expect(pd4.denotations_num).to eq(999)
    end
  end

  describe 'combining filters' do
    it 'updates only project_docs matching both project_id and doc_ids' do
      # Set wrong counts
      ProjectDoc.update_all(denotations_num: 999, blocks_num: 999)

      # Update only project1 + doc1
      ProjectDoc.bulk_update_counts(project_id: project1.id, doc_ids: [doc1.id])

      # Should update pd1 only
      pd1.reload
      expect(pd1.denotations_num).to eq(3)

      # Others should remain unchanged
      pd2.reload
      expect(pd2.denotations_num).to eq(999)

      pd3.reload
      expect(pd3.denotations_num).to eq(999)

      pd4.reload
      expect(pd4.denotations_num).to eq(999)
    end
  end

  describe 'flagged_only option' do
    before do
      pd1.update_column(:flag, true)
      pd2.update_column(:flag, false)
      pd3.update_column(:flag, true)
      pd4.update_column(:flag, false)

      # Set wrong counts
      ProjectDoc.update_all(denotations_num: 999, blocks_num: 999)
    end

    it 'updates only flagged project_docs when flagged_only is true' do
      ProjectDoc.bulk_update_counts(flagged_only: true)

      pd1.reload
      expect(pd1.denotations_num).to eq(3)

      pd3.reload
      expect(pd3.denotations_num).to eq(7)

      # Non-flagged should remain unchanged
      pd2.reload
      expect(pd2.denotations_num).to eq(999)

      pd4.reload
      expect(pd4.denotations_num).to eq(999)
    end

    it 'can combine flagged_only with project_id' do
      ProjectDoc.bulk_update_counts(project_id: project1.id, flagged_only: true)

      # Only pd1 (project1 + flagged)
      pd1.reload
      expect(pd1.denotations_num).to eq(3)

      # All others unchanged
      [pd2, pd3, pd4].each do |pd|
        pd.reload
        expect(pd.denotations_num).to eq(999)
      end
    end
  end

  describe 'update_timestamp option' do
    before do
      # Clear timestamps
      ProjectDoc.update_all(annotations_updated_at: nil)
    end

    it 'updates annotations_updated_at when update_timestamp is true' do
      travel_to Time.current do
        ProjectDoc.bulk_update_counts(update_timestamp: true)

        pd1.reload
        expect(pd1.annotations_updated_at).to be_within(1.second).of(Time.current)

        pd2.reload
        expect(pd2.annotations_updated_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'does not update annotations_updated_at when update_timestamp is false' do
      ProjectDoc.bulk_update_counts(update_timestamp: false)

      pd1.reload
      expect(pd1.annotations_updated_at).to be_nil

      pd2.reload
      expect(pd2.annotations_updated_at).to be_nil
    end

    it 'defaults to not updating timestamp' do
      ProjectDoc.bulk_update_counts

      pd1.reload
      expect(pd1.annotations_updated_at).to be_nil
    end
  end

  describe 'edge cases' do
    it 'handles empty doc_ids array gracefully' do
      expect { ProjectDoc.bulk_update_counts(doc_ids: []) }.not_to raise_error
    end

    it 'handles project_docs with no annotations' do
      ProjectDoc.bulk_update_counts(project_id: project2.id, doc_ids: [doc3.id])

      pd4.reload
      expect(pd4.denotations_num).to eq(0)
      expect(pd4.blocks_num).to eq(0)
    end
  end

  describe 'accuracy after changes' do
    it 'correctly updates counts after annotations are added' do
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      # Add more annotations
      create_list(:denotation, 10, project: project1, doc: doc1)

      # Update again
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      pd1.reload
      expect(pd1.denotations_num).to eq(13)  # 3 + 10
    end

    it 'correctly updates counts after annotations are deleted' do
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      # Delete all annotations
      Denotation.where(project: project1, doc: doc1).delete_all
      Block.where(project: project1, doc: doc1).delete_all

      # Update again
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      pd1.reload
      expect(pd1.denotations_num).to eq(0)
      expect(pd1.blocks_num).to eq(0)
    end
  end
end
