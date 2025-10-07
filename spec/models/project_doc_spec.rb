# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectDoc, type: :model do
  let(:project) { create(:project) }
  let(:doc1) { create(:doc, sourcedb: 'PMC', sourceid: '123') }
  let(:doc2) { create(:doc, sourcedb: 'PMC', sourceid: '456') }
  let(:doc3) { create(:doc, sourcedb: 'PMC', sourceid: '789') }
  let!(:project_doc1) { create(:project_doc, project: project, doc: doc1, denotations_num: 10, blocks_num: 5, relations_num: 3) }
  let!(:project_doc2) { create(:project_doc, project: project, doc: doc2, denotations_num: 20, blocks_num: 8, relations_num: 2) }
  let!(:project_doc3) { create(:project_doc, project: project, doc: doc3, denotations_num: 0, blocks_num: 0, relations_num: 0) }

  describe '.bulk_increment_counts_for_batch' do
    context 'in replace mode' do
      it 'sets counters to new values (not increment)' do
        doc_deltas = {
          doc1.id => { denotations: 50, blocks: 10, relations: 5 },
          doc2.id => { denotations: 30, blocks: 2, relations: 1 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'replace'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(50)  # SET to 50, not increment
        expect(project_doc1.blocks_num).to eq(10)
        expect(project_doc1.relations_num).to eq(5)

        project_doc2.reload
        expect(project_doc2.denotations_num).to eq(30)  # SET to 30
        expect(project_doc2.blocks_num).to eq(2)
        expect(project_doc2.relations_num).to eq(1)
      end

      it 'can set counters to zero' do
        doc_deltas = {
          doc1.id => { denotations: 0, blocks: 0, relations: 0 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'replace'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(0)
        expect(project_doc1.blocks_num).to eq(0)
        expect(project_doc1.relations_num).to eq(0)
      end

      it 'only updates specified documents' do
        doc_deltas = {
          doc1.id => { denotations: 100, blocks: 50, relations: 25 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'replace'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(100)

        # doc2 should remain unchanged
        project_doc2.reload
        expect(project_doc2.denotations_num).to eq(20)
        expect(project_doc2.blocks_num).to eq(8)
      end
    end

    context 'in add mode' do
      it 'increments counters by delta values' do
        doc_deltas = {
          doc1.id => { denotations: 15, blocks: 3, relations: 2 },
          doc2.id => { denotations: 10, blocks: 1, relations: 0 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'add'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(25)  # 10 + 15
        expect(project_doc1.blocks_num).to eq(8)        # 5 + 3
        expect(project_doc1.relations_num).to eq(5)     # 3 + 2

        project_doc2.reload
        expect(project_doc2.denotations_num).to eq(30)  # 20 + 10
        expect(project_doc2.blocks_num).to eq(9)        # 8 + 1
        expect(project_doc2.relations_num).to eq(2)     # 2 + 0
      end

      it 'handles zero increments' do
        doc_deltas = {
          doc1.id => { denotations: 0, blocks: 0, relations: 0 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'add'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(10)  # unchanged
        expect(project_doc1.blocks_num).to eq(5)
        expect(project_doc1.relations_num).to eq(3)
      end

      it 'handles NULL values with COALESCE' do
        # project_doc3 has counters set to 0
        doc_deltas = {
          doc3.id => { denotations: 5, blocks: 2, relations: 1 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'add'
        )

        project_doc3.reload
        expect(project_doc3.denotations_num).to eq(5)
        expect(project_doc3.blocks_num).to eq(2)
        expect(project_doc3.relations_num).to eq(1)
      end
    end

    context 'edge cases' do
      it 'handles empty doc_deltas gracefully' do
        expect {
          ProjectDoc.bulk_increment_counts_for_batch(
            project_id: project.id,
            doc_deltas: {},
            mode: 'add'
          )
        }.not_to raise_error

        # Counters should remain unchanged
        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(10)
      end

      it 'updates multiple documents in single transaction' do
        doc_deltas = {
          doc1.id => { denotations: 100, blocks: 50, relations: 25 },
          doc2.id => { denotations: 200, blocks: 100, relations: 50 },
          doc3.id => { denotations: 300, blocks: 150, relations: 75 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'replace'
        )

        project_doc1.reload
        project_doc2.reload
        project_doc3.reload

        expect(project_doc1.denotations_num).to eq(100)
        expect(project_doc2.denotations_num).to eq(200)
        expect(project_doc3.denotations_num).to eq(300)
      end

      it 'only affects the specified project' do
        other_project = create(:project)
        other_project_doc1 = create(:project_doc, project: other_project, doc: doc1, denotations_num: 999)

        doc_deltas = {
          doc1.id => { denotations: 50, blocks: 10, relations: 5 }
        }

        ProjectDoc.bulk_increment_counts_for_batch(
          project_id: project.id,
          doc_deltas: doc_deltas,
          mode: 'replace'
        )

        project_doc1.reload
        expect(project_doc1.denotations_num).to eq(50)

        # Other project's project_doc should remain unchanged
        other_project_doc1.reload
        expect(other_project_doc1.denotations_num).to eq(999)
      end
    end
  end
end
