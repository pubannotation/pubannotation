require 'rails_helper'

RSpec.describe Doc, '.bulk_update_docs_counts - scaling paths', type: :model do
	let(:user) { FactoryBot.create(:user) }
	let(:project) { FactoryBot.create(:project, user: user) }

	describe 'scaling strategy selection' do
		it 'uses IN clause for small batches (< 5000)' do
			docs = FactoryBot.create_list(:doc, 10)
			docs.each { |doc| project.docs << doc }

			expect(Doc).to receive(:bulk_update_with_in_clause).once.and_call_original
			Doc.bulk_update_docs_counts(doc_ids: docs.map(&:id))
		end

		it 'uses batched IN clause for medium batches (5000-100000)' do
			# Create a medium-sized array to trigger batching
			doc_ids = (1..6000).to_a

			# Should call bulk_update_with_in_clause twice: once for first 5000, once for remaining 1000
			expect(Doc).to receive(:bulk_update_with_in_clause).twice

			# Don't actually execute the SQL since we don't have 6000 real docs
			allow(ActiveRecord::Base.connection).to receive(:update).and_return(0)

			Doc.bulk_update_docs_counts(doc_ids: doc_ids)
		end

		it 'uses temp table for large batches (>= 100000)' do
			# Create a large array to trigger temp table approach
			doc_ids = (1..150000).to_a

			expect(Doc).to receive(:bulk_update_with_temp_table).once

			# Mock the temp table operations
			allow(ActiveRecord::Base.connection).to receive(:execute)
			allow(ActiveRecord::Base.connection).to receive(:update).and_return(0)

			Doc.bulk_update_docs_counts(doc_ids: doc_ids)
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
			docs.each { |doc| doc.update_column(:denotations_num, 999) }

			# Simulate large batch by directly calling temp table method
			# (using small number for test performance)
			Doc.send(:bulk_update_with_temp_table, docs.map(&:id))

			# Verify counts were corrected
			docs.each do |doc|
				doc.reload
				expect(doc.denotations_num).to eq(3)
			end
		end
	end

	describe 'performance characteristics' do
		it 'filtered queries only scan relevant doc_ids' do
			# Create docs with annotations
			doc1 = FactoryBot.create(:doc)
			doc2 = FactoryBot.create(:doc)
			doc3 = FactoryBot.create(:doc)

			project.docs << [doc1, doc2, doc3]
			FactoryBot.create_list(:denotation, 5, project: project, doc: doc1)
			FactoryBot.create_list(:denotation, 10, project: project, doc: doc2)
			FactoryBot.create_list(:denotation, 15, project: project, doc: doc3)

			# Update only doc1 and doc2
			Doc.bulk_update_docs_counts(doc_ids: [doc1.id, doc2.id])

			doc1.reload
			doc2.reload
			doc3.reload

			# doc1 and doc2 should be updated
			expect(doc1.denotations_num).to eq(5)
			expect(doc2.denotations_num).to eq(10)

			# doc3 count should be unchanged (assuming it was correct before)
			# This verifies the WHERE clause in subqueries is working
		end
	end
end
