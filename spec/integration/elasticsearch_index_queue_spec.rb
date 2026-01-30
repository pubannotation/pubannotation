# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Elasticsearch::IndexQueue, :elasticsearch do
  let(:queue) { described_class.new }

  before do
    queue.clear
  end

  after do
    queue.clear
  end

  describe 'queue operations' do
    describe '#enqueue_doc' do
      it 'adds document to queue' do
        expect { queue.enqueue_doc(doc_id: 1, operation: :index_doc) }
          .to change { queue.queue_size }.by(1)
      end

      it 'validates operation type' do
        expect {
          queue.enqueue_doc(doc_id: 1, operation: :invalid_op)
        }.to raise_error(ArgumentError, /Invalid operation/)
      end
    end

    describe '#enqueue_docs' do
      it 'adds multiple documents to queue' do
        expect { queue.enqueue_docs(doc_ids: [1, 2, 3], operation: :index_doc) }
          .to change { queue.queue_size }.by(3)
      end

      it 'handles empty array' do
        expect { queue.enqueue_docs(doc_ids: [], operation: :index_doc) }
          .not_to change { queue.queue_size }
      end
    end

    describe '#enqueue_project_membership' do
      it 'adds membership operation to queue' do
        expect {
          queue.enqueue_project_membership(doc_id: 1, project_id: 5, operation: :add_project_membership)
        }.to change { queue.queue_size }.by(1)
      end
    end

    describe '#pop_batch' do
      before do
        5.times { |i| queue.enqueue_doc(doc_id: i, operation: :index_doc) }
      end

      it 'returns requested batch size' do
        batch = queue.pop_batch(batch_size: 3)

        expect(batch.size).to eq(3)
        expect(queue.queue_size).to eq(2)
      end

      it 'returns all remaining if less than batch size' do
        batch = queue.pop_batch(batch_size: 10)

        expect(batch.size).to eq(5)
        expect(queue.queue_size).to eq(0)
      end

      it 'returns parsed operation hashes' do
        batch = queue.pop_batch(batch_size: 1)

        expect(batch.first).to include(
          type: 'doc',
          doc_id: 0,
          operation: 'index_doc'
        )
      end
    end

    describe '#queue_size' do
      it 'returns current queue size' do
        expect(queue.queue_size).to eq(0)

        3.times { |i| queue.enqueue_doc(doc_id: i, operation: :index_doc) }

        expect(queue.queue_size).to eq(3)
      end
    end

    describe '#empty?' do
      it 'returns true when queue is empty' do
        expect(queue.empty?).to be true
      end

      it 'returns false when queue has items' do
        queue.enqueue_doc(doc_id: 1, operation: :index_doc)
        expect(queue.empty?).to be false
      end
    end

    describe '#clear' do
      it 'removes all items from queue' do
        5.times { |i| queue.enqueue_doc(doc_id: i, operation: :index_doc) }

        queue.clear

        expect(queue.queue_size).to eq(0)
      end
    end
  end

  describe 'batch processing' do
    describe '#process_batch' do
      let!(:doc) { create(:doc, body: 'Test document for indexing') }

      it 'indexes documents to Elasticsearch' do
        batch = [{ type: 'doc', doc_id: doc.id, operation: 'index_doc', queued_at: Time.current.iso8601 }]

        result = queue.process_batch(batch)
        ElasticsearchTestHelper.refresh_index

        expect(result[:processed]).to eq(1)
        expect(result[:errors]).to be_empty

        # Verify document is in ES
        response = ELASTICSEARCH_CLIENT.get(
          index: ElasticsearchTestHelper::TEST_INDEX_NAME,
          id: doc.id.to_s,
          routing: doc.id.to_s
        )
        expect(response['found']).to be true
        expect(response.dig('_source', 'body')).to eq(doc.body)
      end

      it 'deletes documents from Elasticsearch' do
        # First index the document
        ElasticsearchTestHelper.index_document(doc)
        ElasticsearchTestHelper.refresh_index

        batch = [{ type: 'doc', doc_id: doc.id, operation: 'delete_doc', queued_at: Time.current.iso8601 }]

        result = queue.process_batch(batch)
        ElasticsearchTestHelper.refresh_index

        expect(result[:processed]).to eq(1)

        # Verify document is deleted
        expect {
          ELASTICSEARCH_CLIENT.get(
            index: ElasticsearchTestHelper::TEST_INDEX_NAME,
            id: doc.id.to_s,
            routing: doc.id.to_s
          )
        }.to raise_error(Elastic::Transport::Transport::Errors::NotFound)
      end

      it 'adds project memberships' do
        project = create(:project, name: 'TestProject')
        ElasticsearchTestHelper.index_document(doc)

        batch = [{
          type: 'project_membership',
          doc_id: doc.id,
          project_id: project.id,
          operation: 'add_project_membership',
          queued_at: Time.current.iso8601
        }]

        result = queue.process_batch(batch)
        ElasticsearchTestHelper.refresh_index

        expect(result[:processed]).to eq(1)

        # Verify membership exists
        membership_id = "#{doc.id}_#{project.id}"
        response = ELASTICSEARCH_CLIENT.get(
          index: ElasticsearchTestHelper::TEST_INDEX_NAME,
          id: membership_id,
          routing: doc.id.to_s
        )
        expect(response['found']).to be true
        expect(response.dig('_source', 'project_id')).to eq(project.id)
      end

      it 'handles non-existent documents gracefully' do
        batch = [{ type: 'doc', doc_id: 999999, operation: 'index_doc', queued_at: Time.current.iso8601 }]

        result = queue.process_batch(batch)

        expect(result[:errors]).to be_empty  # No error, just skipped
      end

      it 'returns empty result for empty batch' do
        result = queue.process_batch([])

        expect(result).to eq({ processed: 0, errors: [] })
      end
    end

    describe '#process_all' do
      let!(:docs) { create_list(:doc, 3) }

      before do
        # Clear queue after doc creation (after_commit callbacks add to queue)
        queue.clear
        # Manually enqueue for controlled testing
        docs.each { |doc| queue.enqueue_doc(doc_id: doc.id, operation: :index_doc) }
      end

      it 'processes all queued operations' do
        expect(queue.queue_size).to eq(3)

        total = queue.process_all
        ElasticsearchTestHelper.refresh_index

        expect(total).to eq(3)
        expect(queue.queue_size).to eq(0)
        expect(ElasticsearchTestHelper.document_count).to eq(3)
      end
    end
  end

  describe 'class methods' do
    describe '.index_doc' do
      it 'enqueues via singleton instance' do
        expect { described_class.index_doc(1) }
          .to change { described_class.queue_size }.by(1)
      end
    end

    describe '.delete_doc' do
      it 'enqueues delete operation' do
        described_class.delete_doc(1)
        batch = queue.pop_batch(batch_size: 1)

        expect(batch.first[:operation]).to eq('delete_doc')
      end
    end

    describe '.add_project_membership' do
      it 'enqueues membership operation' do
        described_class.add_project_membership(doc_id: 1, project_id: 5)
        batch = queue.pop_batch(batch_size: 1)

        expect(batch.first[:operation]).to eq('add_project_membership')
        expect(batch.first[:project_id]).to eq(5)
      end
    end
  end
end
