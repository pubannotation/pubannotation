# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Embedding Workflow Integration', :elasticsearch do
  let(:sample_embedding) { Array.new(768) { |i| Math.sin(i * 0.1) } }

  # Tests that require RRF (Platinum license)
  describe 'document embedding and semantic search', if: ElasticsearchTestHelper.rrf_available? do
    let!(:cancer_doc) { create(:doc, body: 'p53 tumor suppressor protein plays a crucial role in cancer prevention') }
    let!(:diabetes_doc) { create(:doc, body: 'Insulin resistance is a hallmark of type 2 diabetes mellitus') }
    let!(:heart_doc) { create(:doc, body: 'Cardiovascular disease and myocardial infarction risk factors') }

    before do
      cancer_embedding = Array.new(768) { |i| Math.sin(i * 0.1) }
      diabetes_embedding = Array.new(768) { |i| Math.cos(i * 0.1) }
      heart_embedding = Array.new(768) { |i| Math.sin(i * 0.2) }

      ElasticsearchTestHelper.index_document(cancer_doc, embedding: cancer_embedding)
      ElasticsearchTestHelper.index_document(diabetes_doc, embedding: diabetes_embedding)
      ElasticsearchTestHelper.index_document(heart_doc, embedding: heart_embedding)
      ElasticsearchTestHelper.refresh_index
    end

    it 'can search using vector similarity' do
      query_embedding = Array.new(768) { |i| Math.sin(i * 0.1) }
      allow(EmbeddingService).to receive(:generate).and_return(query_embedding)

      results = Doc.hybrid_search('tumor suppressor', page: 1, per: 10)

      expect(results).to be_present
      expect(results.map(&:id)).to include(cancer_doc.id)
    end

    it 'combines keyword and semantic relevance' do
      allow(EmbeddingService).to receive(:generate).and_return(sample_embedding)

      results = Doc.hybrid_search('cancer', page: 1, per: 10)

      expect(results.total).to be >= 1
    end
  end

  describe 'embedding generation job with ES update' do
    let!(:doc) { create(:doc, body: 'BRCA1 mutations increase breast cancer risk') }

    before do
      ElasticsearchTestHelper.index_document(doc)
      ElasticsearchTestHelper.refresh_index
    end

    it 'updates document with embedding in Elasticsearch' do
      allow(EmbeddingService).to receive(:generate_batch).and_return([sample_embedding])

      GenerateEmbeddingsJob.perform_now(doc_ids: [doc.id])
      ElasticsearchTestHelper.refresh_index

      response = ELASTICSEARCH_CLIENT.get(
        index: ElasticsearchTestHelper::TEST_INDEX_NAME,
        id: doc.id.to_s,
        routing: doc.id.to_s
      )

      expect(response.dig('_source', 'body_embedding')).to be_present
      expect(response.dig('_source', 'body_embedding').size).to eq(768)
    end
  end

  describe 'EmbeddingService integration' do
    context 'when embedding server is available', if: EmbeddingService.available? do
      it 'generates real embeddings' do
        embedding = EmbeddingService.generate('p53 tumor suppressor protein')

        expect(embedding).to be_an(Array)
        expect(embedding.size).to eq(768)
        expect(embedding.all? { |v| v.is_a?(Numeric) }).to be true
      end

      it 'generates batch embeddings' do
        texts = ['cancer cells', 'diabetes treatment', 'heart disease']
        embeddings = EmbeddingService.generate_batch(texts)

        expect(embeddings.size).to eq(3)
        expect(embeddings.all? { |e| e.is_a?(Array) && e.size == 768 }).to be true
      end

      it 'handles long text with truncation' do
        long_text = 'word ' * 1000
        embedding = EmbeddingService.generate(long_text)

        expect(embedding).to be_an(Array)
        expect(embedding.size).to eq(768)
      end
    end

    context 'when embedding server is not available', unless: EmbeddingService.available? do
      it 'returns nil gracefully' do
        embedding = EmbeddingService.generate('test text')
        expect(embedding).to be_nil
      end
    end
  end

  describe 'full workflow: index -> embed -> search' do
    let(:project) { create(:project, name: 'Oncology') }
    let!(:doc1) { create(:doc, sourcedb: 'PubMed', body: 'EGFR mutations in non-small cell lung cancer') }
    let!(:doc2) { create(:doc, sourcedb: 'PubMed', body: 'HER2 positive breast cancer treatment with trastuzumab') }
    let!(:doc3) { create(:doc, sourcedb: 'PMC', body: 'Weather patterns and climate change analysis') }

    before do
      create(:project_doc, project: project, doc: doc1)
      create(:project_doc, project: project, doc: doc2)

      embeddings = {
        doc1.id => Array.new(768) { |i| Math.sin(i * 0.1) },
        doc2.id => Array.new(768) { |i| Math.sin(i * 0.11) },
        doc3.id => Array.new(768) { |i| Math.cos(i * 0.5) }
      }

      [doc1, doc2, doc3].each do |doc|
        ElasticsearchTestHelper.index_document(doc, embedding: embeddings[doc.id])
      end

      [doc1, doc2].each do |doc|
        ElasticsearchTestHelper.index_project_membership(doc.id, project.id, project.name)
      end

      ElasticsearchTestHelper.refresh_index
    end

    it 'supports BM25 search across all documents' do
      results = Doc.search_by_elasticsearch('cancer', nil, nil, 1, 10)

      expect(results.total).to eq(2)
      expect(results.map { |r| r.id.to_i }).to contain_exactly(doc1.id, doc2.id)
    end

    it 'supports filtered search within project' do
      results = Doc.search_by_elasticsearch('cancer', project, nil, 1, 10)

      expect(results.total).to eq(2)
    end

    it 'supports filtered search by sourcedb' do
      # Search for a term in doc3 (PMC) and filter by sourcedb
      results = Doc.search_by_elasticsearch('weather climate', nil, 'PMC', 1, 10)

      expect(results.total).to eq(1)
      expect(results.first.id.to_i).to eq(doc3.id)
    end

    # Hybrid search tests - only run with Platinum license
    context 'with RRF support', if: ElasticsearchTestHelper.rrf_available? do
      it 'supports hybrid search with project filter' do
        allow(EmbeddingService).to receive(:generate)
          .and_return(Array.new(768) { |i| Math.sin(i * 0.1) })

        results = Doc.hybrid_search('lung cancer EGFR', project: project, page: 1, per: 10)

        expect(results).to be_present
        expect(results.map(&:id)).to include(doc1.id)
      end

      it 'ranks semantically similar documents higher in hybrid search' do
        allow(EmbeddingService).to receive(:generate)
          .and_return(Array.new(768) { |i| Math.sin(i * 0.1) })

        results = Doc.hybrid_search('cancer treatment', page: 1, per: 10)

        cancer_doc_positions = results.map(&:id).take(2)
        expect(cancer_doc_positions).not_to include(doc3.id)
      end
    end
  end
end
