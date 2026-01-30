# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateEmbeddingsJob, type: :job do
  let(:sample_embedding) { Array.new(768) { rand(-1.0..1.0) } }

  # Mock Elasticsearch client
  let(:es_client) { instance_double('Elasticsearch::Client') }

  before do
    # Stub the Elasticsearch client
    stub_const('ELASTICSEARCH_CLIENT', es_client)
    stub_const('ELASTICSEARCH_INDEX_ALIAS', 'pubannotation_docs_test')

    # Default: successful bulk response
    allow(es_client).to receive(:bulk).and_return({ 'errors' => false, 'items' => [] })
  end

  describe '#perform' do
    context 'with no documents' do
      it 'completes without error' do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context 'with documents' do
      let!(:docs) { create_list(:doc, 5) }
      let(:batch_embeddings) { docs.map { sample_embedding } }

      before do
        allow(EmbeddingService).to receive(:generate_batch).and_return(batch_embeddings)
      end

      it 'generates embeddings for all documents' do
        described_class.perform_now

        expect(EmbeddingService).to have_received(:generate_batch).at_least(:once)
      end

      it 'sends bulk update to Elasticsearch' do
        described_class.perform_now

        expect(es_client).to have_received(:bulk).with(
          hash_including(body: array_including(
            hash_including(:update),
            hash_including(doc: hash_including(:body_embedding))
          ))
        )
      end

      it 'processes documents in batches' do
        # Create more docs than BATCH_SIZE
        create_list(:doc, GenerateEmbeddingsJob::BATCH_SIZE + 10)
        all_docs = Doc.all
        batch_embeddings_large = all_docs.map { sample_embedding }

        allow(EmbeddingService).to receive(:generate_batch).and_return(batch_embeddings_large.take(GenerateEmbeddingsJob::BATCH_SIZE))

        described_class.perform_now

        # Should have called generate_batch multiple times
        expect(EmbeddingService).to have_received(:generate_batch).at_least(2).times
      end
    end

    context 'with specific doc_ids' do
      let!(:docs) { create_list(:doc, 10) }
      let(:target_ids) { docs.first(3).map(&:id) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([sample_embedding, sample_embedding, sample_embedding])
      end

      it 'only processes specified documents' do
        described_class.perform_now(doc_ids: target_ids)

        expect(EmbeddingService).to have_received(:generate_batch) do |texts|
          expect(texts.size).to eq(3)
        end
      end
    end

    context 'with project_id' do
      let(:project) { create(:project) }
      let!(:project_docs) { create_list(:doc, 3) }
      let!(:other_docs) { create_list(:doc, 2) }

      before do
        project_docs.each { |doc| create(:project_doc, project: project, doc: doc) }
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return(project_docs.map { sample_embedding })
      end

      it 'only processes documents in the project' do
        described_class.perform_now(project_id: project.id)

        expect(EmbeddingService).to have_received(:generate_batch) do |texts|
          expect(texts.size).to eq(3)
        end
      end

      it 'handles non-existent project gracefully' do
        expect { described_class.perform_now(project_id: 999999) }.not_to raise_error
      end
    end

    context 'when embedding service fails' do
      let!(:docs) { create_list(:doc, 3) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([nil, nil, nil])
      end

      it 'tracks failed documents' do
        job = described_class.new
        job.perform

        expect(job.instance_variable_get(:@failed)).to eq(3)
        expect(job.instance_variable_get(:@processed)).to eq(0)
      end

      it 'does not send empty bulk request to ES' do
        described_class.perform_now

        expect(es_client).not_to have_received(:bulk)
      end
    end

    context 'when some embeddings fail' do
      let!(:docs) { create_list(:doc, 3) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([sample_embedding, nil, sample_embedding])
      end

      it 'tracks partial success' do
        job = described_class.new
        job.perform

        expect(job.instance_variable_get(:@processed)).to eq(2)
        expect(job.instance_variable_get(:@failed)).to eq(1)
      end
    end

    context 'when Elasticsearch bulk update fails' do
      let!(:docs) { create_list(:doc, 3) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([sample_embedding, sample_embedding, sample_embedding])
        allow(es_client).to receive(:bulk)
          .and_raise(StandardError.new('ES connection failed'))
      end

      it 'handles ES errors gracefully' do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context 'when Elasticsearch returns errors' do
      let!(:docs) { create_list(:doc, 3) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([sample_embedding, sample_embedding, sample_embedding])
        allow(es_client).to receive(:bulk).and_return({
          'errors' => true,
          'items' => [
            { 'update' => { 'status' => 200 } },
            { 'update' => { 'error' => { 'type' => 'mapper_parsing_exception' } } },
            { 'update' => { 'status' => 200 } }
          ]
        })
      end

      it 'tracks ES errors as failures' do
        job = described_class.new
        job.perform

        # 3 initially processed, then 1 error detected
        expect(job.instance_variable_get(:@failed)).to be >= 1
      end
    end

    context 'with offset option' do
      let!(:docs) { create_list(:doc, 10) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return(docs.drop(5).map { sample_embedding })
      end

      it 'starts from the specified offset' do
        described_class.perform_now(offset: 5)

        expect(EmbeddingService).to have_received(:generate_batch) do |texts|
          expect(texts.size).to eq(5)  # Only docs after offset
        end
      end
    end

    context 'with limit option' do
      let!(:docs) { create_list(:doc, 10) }

      before do
        allow(EmbeddingService).to receive(:generate_batch)
          .and_return([sample_embedding, sample_embedding, sample_embedding])
      end

      it 'limits the number of documents processed' do
        described_class.perform_now(limit: 3)

        expect(EmbeddingService).to have_received(:generate_batch) do |texts|
          expect(texts.size).to eq(3)
        end
      end
    end
  end

  describe 'BATCH_SIZE' do
    it 'is set to 50' do
      expect(described_class::BATCH_SIZE).to eq(50)
    end
  end
end
