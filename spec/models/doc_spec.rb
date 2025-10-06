# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'factory' do
    it 'creates a valid doc' do
      doc = create(:doc)
      expect(doc).to be_persisted
      expect(doc.sourcedb).to be_present
      expect(doc.sourceid).to be_present
      expect(doc.body).to be_present
    end
  end

  describe 'validations' do
    it 'requires sourcedb and sourceid' do
      doc = Doc.new
      expect(doc).not_to be_valid
    end
  end

  describe '.bulk_increment_counts_for_batch' do
    let!(:doc1) { create(:doc, sourcedb: 'PMC', sourceid: '123', denotations_num: 100, blocks_num: 50, relations_num: 25) }
    let!(:doc2) { create(:doc, sourcedb: 'PMC', sourceid: '456', denotations_num: 200, blocks_num: 80, relations_num: 40) }
    let!(:doc3) { create(:doc, sourcedb: 'PMC', sourceid: '789', denotations_num: 0, blocks_num: 0, relations_num: 0) }

    context 'with positive deltas (add mode or more annotations in replace mode)' do
      it 'increments counters by delta values' do
        doc_deltas = {
          doc1.id => { denotations: 30, blocks: 10, relations: 5 },  # net delta
          doc2.id => { denotations: 20, blocks: 5, relations: 2 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        expect(doc1.denotations_num).to eq(130)  # 100 + 30
        expect(doc1.blocks_num).to eq(60)        # 50 + 10
        expect(doc1.relations_num).to eq(30)     # 25 + 5

        doc2.reload
        expect(doc2.denotations_num).to eq(220)  # 200 + 20
        expect(doc2.blocks_num).to eq(85)        # 80 + 5
        expect(doc2.relations_num).to eq(42)     # 40 + 2
      end
    end

    context 'with negative deltas (fewer annotations in replace mode)' do
      it 'decrements counters correctly' do
        # Scenario: Doc had 100 denotations from this project, now has only 70
        # Net delta = 70 - 100 = -30
        doc_deltas = {
          doc1.id => { denotations: -30, blocks: -10, relations: -5 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        expect(doc1.denotations_num).to eq(70)   # 100 + (-30)
        expect(doc1.blocks_num).to eq(40)        # 50 + (-10)
        expect(doc1.relations_num).to eq(20)     # 25 + (-5)
      end

      it 'handles complete removal of annotations (delta = old_count)' do
        # All annotations removed in replace mode
        doc_deltas = {
          doc1.id => { denotations: -100, blocks: -50, relations: -25 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        expect(doc1.denotations_num).to eq(0)    # 100 + (-100)
        expect(doc1.blocks_num).to eq(0)         # 50 + (-50)
        expect(doc1.relations_num).to eq(0)      # 25 + (-25)
      end
    end

    context 'with zero deltas' do
      it 'leaves counters unchanged' do
        doc_deltas = {
          doc1.id => { denotations: 0, blocks: 0, relations: 0 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        expect(doc1.denotations_num).to eq(100)  # unchanged
        expect(doc1.blocks_num).to eq(50)
        expect(doc1.relations_num).to eq(25)
      end
    end

    context 'cross-project aggregates' do
      let(:project_a) { create(:project) }
      let(:project_b) { create(:project) }
      let(:shared_doc) { create(:doc, denotations_num: 100, blocks_num: 50, relations_num: 25) }

      before do
        # shared_doc has annotations from both projects:
        # ProjectA: 50 denotations, 30 blocks, 15 relations
        # ProjectB: 50 denotations, 20 blocks, 10 relations
        # Total: 100 denotations, 50 blocks, 25 relations
      end

      it 'correctly updates aggregate when one project replaces its annotations' do
        # ProjectA replaces with 60 denotations (was 50, now 60)
        # Net delta for ProjectA: 60 - 50 = +10
        # Expected total: 100 + 10 = 110
        doc_deltas = {
          shared_doc.id => { denotations: 10, blocks: 5, relations: 2 }  # net delta
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        shared_doc.reload
        expect(shared_doc.denotations_num).to eq(110)  # 100 + 10
        expect(shared_doc.blocks_num).to eq(55)        # 50 + 5
        expect(shared_doc.relations_num).to eq(27)     # 25 + 2
      end

      it 'correctly updates aggregate when one project removes annotations' do
        # ProjectA removes all its annotations (was 50, now 0)
        # Net delta: 0 - 50 = -50
        # Expected total: 100 - 50 = 50 (only ProjectB remains)
        doc_deltas = {
          shared_doc.id => { denotations: -50, blocks: -30, relations: -15 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        shared_doc.reload
        expect(shared_doc.denotations_num).to eq(50)   # 100 - 50
        expect(shared_doc.blocks_num).to eq(20)        # 50 - 30
        expect(shared_doc.relations_num).to eq(10)     # 25 - 15
      end
    end

    context 'handles NULL values with COALESCE' do
      it 'treats NULL as 0 when incrementing' do
        # doc3 has all counters set to 0 (could be NULL in DB)
        doc_deltas = {
          doc3.id => { denotations: 15, blocks: 8, relations: 4 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc3.reload
        expect(doc3.denotations_num).to eq(15)
        expect(doc3.blocks_num).to eq(8)
        expect(doc3.relations_num).to eq(4)
      end
    end

    context 'edge cases' do
      it 'handles empty doc_deltas gracefully' do
        expect {
          Doc.bulk_increment_counts_for_batch(doc_deltas: {})
        }.not_to raise_error

        # Counters should remain unchanged
        doc1.reload
        expect(doc1.denotations_num).to eq(100)
      end

      it 'updates multiple documents in single transaction' do
        doc_deltas = {
          doc1.id => { denotations: 10, blocks: 5, relations: 2 },
          doc2.id => { denotations: -20, blocks: -10, relations: -5 },
          doc3.id => { denotations: 30, blocks: 15, relations: 8 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        doc2.reload
        doc3.reload

        expect(doc1.denotations_num).to eq(110)  # 100 + 10
        expect(doc2.denotations_num).to eq(180)  # 200 - 20
        expect(doc3.denotations_num).to eq(30)   # 0 + 30
      end

      it 'only updates specified documents' do
        doc_deltas = {
          doc1.id => { denotations: 50, blocks: 25, relations: 10 }
        }

        Doc.bulk_increment_counts_for_batch(doc_deltas: doc_deltas)

        doc1.reload
        expect(doc1.denotations_num).to eq(150)

        # doc2 and doc3 should remain unchanged
        doc2.reload
        expect(doc2.denotations_num).to eq(200)

        doc3.reload
        expect(doc3.denotations_num).to eq(0)
      end
    end
  end
end
