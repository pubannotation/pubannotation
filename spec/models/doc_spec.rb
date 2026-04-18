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

  describe '#get_relations_count with span' do
    let(:project) { create(:project) }
    let(:doc) { create(:doc) }
    let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

    # Denotations at known positions
    let!(:d_0_5)   { create(:denotation, project: project, doc: doc, hid: 'T1', begin: 0,   end: 5) }
    let!(:d_10_20) { create(:denotation, project: project, doc: doc, hid: 'T2', begin: 10,  end: 20) }
    let!(:d_30_40) { create(:denotation, project: project, doc: doc, hid: 'T3', begin: 30,  end: 40) }
    let!(:d_90_100){ create(:denotation, project: project, doc: doc, hid: 'T4', begin: 90,  end: 100) }

    # Relations
    let!(:r_inside) {
      create(:relation, project: project, doc: doc, hid: 'R1',
             subj_type: 'Denotation', subj_id: d_0_5.id,
             obj_type: 'Denotation', obj_id: d_10_20.id)
    }
    let!(:r_straddle) {
      # subj inside [0,50], obj outside
      create(:relation, project: project, doc: doc, hid: 'R2',
             subj_type: 'Denotation', subj_id: d_10_20.id,
             obj_type: 'Denotation', obj_id: d_90_100.id)
    }
    let!(:r_outside) {
      create(:relation, project: project, doc: doc, hid: 'R3',
             subj_type: 'Denotation', subj_id: d_90_100.id,
             obj_type: 'Denotation', obj_id: d_90_100.id)
    }

    it 'returns 0 when no relations fall within the span' do
      expect(doc.get_relations_count(project.id, begin: 50, end: 60)).to eq(0)
    end

    it 'counts only relations whose subj and obj are fully inside the span' do
      expect(doc.get_relations_count(project.id, begin: 0, end: 50)).to eq(1)
    end

    it 'excludes relations that straddle the span boundary' do
      # [0,25] contains r_inside but not r_straddle (obj at 90-100) nor r_outside
      expect(doc.get_relations_count(project.id, begin: 0, end: 25)).to eq(1)
    end

    it 'includes all relations when the span covers the whole doc' do
      expect(doc.get_relations_count(project.id, begin: 0, end: 1000)).to eq(3)
    end

    it 'is inclusive at the span boundaries' do
      # r_inside uses d_0_5 (begin=0) and d_10_20 (end=20).
      # A span exactly matching those bounds must include it.
      expect(doc.get_relations_count(project.id, begin: 0, end: 20)).to eq(1)

      # Shrinking by one in either direction must drop it.
      expect(doc.get_relations_count(project.id, begin: 1, end: 20)).to eq(0)
      expect(doc.get_relations_count(project.id, begin: 0, end: 19)).to eq(0)
    end

    it 'excludes relations whose subj or obj is not a Denotation' do
      # The JOIN narrows to subj_type='Denotation' AND obj_type='Denotation'.
      # Block-typed endpoints are intentionally out of scope for this count,
      # matching the domain definition of Relation (denotation-to-denotation).
      block = create(:block, project: project, doc: doc, hid: 'B1', begin: 0, end: 5)
      create(:relation, project: project, doc: doc, hid: 'R4',
             subj_type: 'Block', subj_id: block.id,
             obj_type: 'Denotation', obj_id: d_10_20.id)

      # Count for [0, 50] is unchanged — only r_inside still qualifies.
      expect(doc.get_relations_count(project.id, begin: 0, end: 50)).to eq(1)
    end

    it 'runs as a single SQL query (no N+1)' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:sql] =~ /\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/
      end

      doc.get_relations_count(project.id, begin: 0, end: 1000)

      ActiveSupport::Notifications.unsubscribe(subscriber)
      expect(queries.size).to eq(1)
      expect(queries.first).to match(/COUNT/i)
      expect(queries.first).to match(/JOIN.*denotations/i)
    end
  end
end
