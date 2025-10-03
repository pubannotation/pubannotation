require 'rails_helper'

RSpec.describe ProjectDoc, '.bulk_update_counts - scaling paths', type: :model do
  let(:user) { FactoryBot.create(:user) }
  let(:project) { FactoryBot.create(:project, user: user) }

  describe 'scaling strategy selection' do
    it 'uses direct implementation for small batches (< 5000)' do
      docs = FactoryBot.create_list(:doc, 10)
      docs.each { |doc| project.docs << doc }

      expect(ProjectDoc).to receive(:bulk_update_counts_impl).once.and_call_original
      ProjectDoc.bulk_update_counts(doc_ids: docs.map(&:id))
    end

    it 'uses batched approach for medium batches (5000-100000)' do
      # Create a medium-sized array to trigger batching
      doc_ids = (1..6000).to_a

      # Should call bulk_update_counts_impl twice: once for first 5000, once for remaining 1000
      expect(ProjectDoc).to receive(:bulk_update_counts_impl).twice

      # Don't actually execute the SQL since we don't have 6000 real docs
      allow(ActiveRecord::Base.connection).to receive(:update).and_return(0)

      ProjectDoc.bulk_update_counts(doc_ids: doc_ids)
    end

    it 'uses temp table for large batches (>= 100000)' do
      # Create a large array to trigger temp table approach
      doc_ids = (1..150000).to_a

      expect(ProjectDoc).to receive(:bulk_update_counts_with_temp_table).once

      # Mock the temp table operations
      allow(ActiveRecord::Base.connection).to receive(:execute)
      allow(ActiveRecord::Base.connection).to receive(:update).and_return(0)

      ProjectDoc.bulk_update_counts(doc_ids: doc_ids)
    end
  end

  describe 'filtered aggregation subqueries' do
    let(:project1) { FactoryBot.create(:project, user: user) }
    let(:project2) { FactoryBot.create(:project, user: user) }

    it 'filters by project_id in aggregation subqueries' do
      # Create docs with annotations in multiple projects
      docs = FactoryBot.create_list(:doc, 5)

      docs.each do |doc|
        project1.docs << doc
        project2.docs << doc
        FactoryBot.create_list(:denotation, 3, project: project1, doc: doc)
        FactoryBot.create_list(:denotation, 5, project: project2, doc: doc)
      end

      # Update only project1's project_docs
      ProjectDoc.bulk_update_counts(project_id: project1.id)

      # Verify project1's counts are correct
      project1.project_docs.each do |pd|
        pd.reload
        expect(pd.denotations_num).to eq(3)
      end

      # This test verifies that the WHERE clause in aggregation subqueries works
    end

    it 'filters by doc_ids in aggregation subqueries' do
      doc1 = FactoryBot.create(:doc)
      doc2 = FactoryBot.create(:doc)
      doc3 = FactoryBot.create(:doc)

      [doc1, doc2, doc3].each { |doc| project.docs << doc }

      FactoryBot.create_list(:denotation, 5, project: project, doc: doc1)
      FactoryBot.create_list(:denotation, 10, project: project, doc: doc2)
      FactoryBot.create_list(:denotation, 15, project: project, doc: doc3)

      # Update only doc1 and doc2
      ProjectDoc.bulk_update_counts(doc_ids: [doc1.id, doc2.id])

      pd1 = ProjectDoc.find_by(project: project, doc: doc1)
      pd2 = ProjectDoc.find_by(project: project, doc: doc2)

      pd1.reload
      pd2.reload

      expect(pd1.denotations_num).to eq(5)
      expect(pd2.denotations_num).to eq(10)
    end

    it 'filters by flagged_only in aggregation subqueries' do
      docs = FactoryBot.create_list(:doc, 3)

      docs.each_with_index do |doc, i|
        project.docs << doc
        FactoryBot.create_list(:denotation, (i + 1) * 5, project: project, doc: doc)
      end

      # Flag only first two docs
      ProjectDoc.where(doc: [docs[0], docs[1]]).update_all(flag: true)

      # Update only flagged project_docs
      ProjectDoc.bulk_update_counts(flagged_only: true)

      pd0 = ProjectDoc.find_by(project: project, doc: docs[0])
      pd1 = ProjectDoc.find_by(project: project, doc: docs[1])

      pd0.reload
      pd1.reload

      expect(pd0.denotations_num).to eq(5)
      expect(pd1.denotations_num).to eq(10)
    end
  end

  describe 'temp table approach (integration test)' do
    it 'correctly updates counts using temp table for large batches' do
      # Create a realistic scenario with multiple docs
      docs = FactoryBot.create_list(:doc, 50)
      docs.each do |doc|
        project.docs << doc
        FactoryBot.create_list(:denotation, 3, project: project, doc: doc)
      end

      # Manually mess up the counts
      ProjectDoc.where(project: project).update_all(denotations_num: 999)

      # Simulate large batch by directly calling temp table method
      ProjectDoc.send(:bulk_update_counts_with_temp_table, project_id: project.id, doc_ids: docs.map(&:id))

      # Verify counts were corrected
      ProjectDoc.where(project: project).each do |pd|
        pd.reload
        expect(pd.denotations_num).to eq(3)
      end
    end

    it 'handles combined filters with temp table' do
      project2 = FactoryBot.create(:project, user: user)
      docs = FactoryBot.create_list(:doc, 30)

      docs.each do |doc|
        project.docs << doc
        project2.docs << doc
        FactoryBot.create_list(:denotation, 2, project: project, doc: doc)
        FactoryBot.create_list(:denotation, 7, project: project2, doc: doc)
      end

      # Mess up counts
      ProjectDoc.update_all(denotations_num: 999)

      # Update only project1 using temp table approach
      ProjectDoc.send(:bulk_update_counts_with_temp_table,
                      project_id: project.id,
                      doc_ids: docs.map(&:id))

      # Verify only project1's counts were updated
      ProjectDoc.where(project: project).each do |pd|
        pd.reload
        expect(pd.denotations_num).to eq(2)
      end

      # project2's counts should still be wrong (999)
      ProjectDoc.where(project: project2).each do |pd|
        pd.reload
        expect(pd.denotations_num).to eq(999)
      end
    end
  end
end
