# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, '.bulk_update_docs_counts', type: :model do
  let!(:project1) { create(:project) }
  let!(:project2) { create(:project) }

  let!(:doc1) { create(:doc) }
  let!(:doc2) { create(:doc) }
  let!(:doc3) { create(:doc) }

  let!(:project_doc1) { create(:project_doc, project: project1, doc: doc1) }
  let!(:project_doc2) { create(:project_doc, project: project1, doc: doc2) }
  let!(:project_doc3) { create(:project_doc, project: project2, doc: doc2) }

  before do
    # Create annotations for doc1
    create_list(:denotation, 3, project: project1, doc: doc1)
    create_list(:block, 2, project: project1, doc: doc1)

    # Create annotations for doc2 from multiple projects
    create_list(:denotation, 5, project: project1, doc: doc2)
    create_list(:block, 1, project: project2, doc: doc2)

    # doc3 has no annotations
  end

  describe 'updating all docs' do
    it 'updates counts for all docs in the database' do
      Doc.bulk_update_docs_counts

      doc1.reload
      expect(doc1.denotations_num).to eq(3)
      expect(doc1.blocks_num).to eq(2)
      expect(doc1.projects_num).to eq(1)

      doc2.reload
      expect(doc2.denotations_num).to eq(5)  # Only from project1
      expect(doc2.blocks_num).to eq(1)        # Only from project2
      expect(doc2.projects_num).to eq(2)      # Two projects

      doc3.reload
      expect(doc3.denotations_num).to eq(0)
      expect(doc3.blocks_num).to eq(0)
      expect(doc3.projects_num).to eq(0)
    end
  end

  describe 'updating specific docs' do
    it 'updates only specified docs' do
      # Set initial wrong counts
      doc1.update_columns(denotations_num: 999, blocks_num: 999, projects_num: 999)
      doc2.update_columns(denotations_num: 999, blocks_num: 999, projects_num: 999)
      doc3.update_columns(denotations_num: 999, blocks_num: 999, projects_num: 999)

      # Update only doc1 and doc2
      Doc.bulk_update_docs_counts(doc_ids: [doc1.id, doc2.id])

      doc1.reload
      expect(doc1.denotations_num).to eq(3)
      expect(doc1.projects_num).to eq(1)

      doc2.reload
      expect(doc2.denotations_num).to eq(5)
      expect(doc2.projects_num).to eq(2)

      # doc3 should remain unchanged
      doc3.reload
      expect(doc3.denotations_num).to eq(999)
      expect(doc3.projects_num).to eq(999)
    end
  end

  describe 'edge cases' do
    it 'handles empty doc_ids array gracefully' do
      expect { Doc.bulk_update_docs_counts(doc_ids: []) }.not_to raise_error
    end

    it 'handles nil doc_ids (updates all)' do
      Doc.bulk_update_docs_counts(doc_ids: nil)

      doc1.reload
      expect(doc1.denotations_num).to eq(3)
    end

    it 'handles docs with no annotations' do
      Doc.bulk_update_docs_counts(doc_ids: [doc3.id])

      doc3.reload
      expect(doc3.denotations_num).to eq(0)
      expect(doc3.blocks_num).to eq(0)
      expect(doc3.projects_num).to eq(0)
    end
  end

  describe 'accuracy' do
    it 'calculates counts across all projects for each doc' do
      # Add more annotations from different projects to doc2
      project3 = create(:project)
      create(:project_doc, project: project3, doc: doc2)
      create_list(:denotation, 10, project: project3, doc: doc2)

      Doc.bulk_update_docs_counts(doc_ids: [doc2.id])

      doc2.reload
      expect(doc2.denotations_num).to eq(15)  # 5 + 10
      expect(doc2.projects_num).to eq(3)      # Three projects now
    end

    it 'sets counts to zero when annotations are deleted' do
      # Delete all annotations
      Denotation.where(doc: doc1).delete_all
      Block.where(doc: doc1).delete_all

      Doc.bulk_update_docs_counts(doc_ids: [doc1.id])

      doc1.reload
      expect(doc1.denotations_num).to eq(0)
      expect(doc1.blocks_num).to eq(0)
    end
  end
end
