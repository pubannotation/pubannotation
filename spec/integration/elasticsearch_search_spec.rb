# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Elasticsearch Search Integration', :elasticsearch do
  let(:sample_embedding) { Array.new(768) { rand(-1.0..1.0) } }

  describe 'BM25 keyword search' do
    let!(:doc1) { create(:doc, sourcedb: 'PubMed', sourceid: '12345', body: 'p53 tumor suppressor protein regulates cell cycle') }
    let!(:doc2) { create(:doc, sourcedb: 'PubMed', sourceid: '12346', body: 'BRCA1 gene mutations in breast cancer patients') }
    let!(:doc3) { create(:doc, sourcedb: 'PMC', sourceid: '67890', body: 'Diabetes treatment with insulin therapy') }

    before do
      [doc1, doc2, doc3].each do |doc|
        ElasticsearchTestHelper.index_document(doc)
      end
      ElasticsearchTestHelper.refresh_index
    end

    it 'finds documents matching keyword query' do
      results = Doc.search_by_elasticsearch('tumor', nil, nil, 1, 10)

      expect(results.total).to eq(1)
      expect(results.first.id.to_i).to eq(doc1.id)
    end

    it 'returns empty results for non-matching query' do
      results = Doc.search_by_elasticsearch('nonexistentterm12345', nil, nil, 1, 10)

      expect(results.total).to eq(0)
    end

    it 'filters by sourcedb' do
      # Search with a common term and filter by sourcedb
      results = Doc.search_by_elasticsearch('protein cancer', nil, 'PubMed', 1, 10)

      expect(results.total).to be >= 1
      expect(results.map(&:sourcedb).uniq).to all(eq('PubMed'))
    end

    it 'provides highlighting for matches' do
      results = Doc.search_by_elasticsearch('breast cancer', nil, nil, 1, 10)

      expect(results.total).to be >= 1
      expect(results.first.highlight.body).to be_present
    end

    it 'paginates results correctly' do
      # Index more documents
      10.times do |i|
        doc = create(:doc, sourcedb: 'PubMed', body: "Document about protein #{i}")
        ElasticsearchTestHelper.index_document(doc)
      end
      ElasticsearchTestHelper.refresh_index

      page1 = Doc.search_by_elasticsearch('protein', nil, nil, 1, 5)
      page2 = Doc.search_by_elasticsearch('protein', nil, nil, 2, 5)

      expect(page1.size).to eq(5)
      expect(page2.size).to be >= 1
      expect(page1.map(&:id) & page2.map(&:id)).to be_empty # No overlap
    end
  end

  describe 'Project filtering with parent-child' do
    let(:project) { create(:project, name: 'TestProject') }
    let!(:doc_in_project) { create(:doc, body: 'Document in the project about genes') }
    let!(:doc_not_in_project) { create(:doc, body: 'Document not in any project about genes') }

    before do
      create(:project_doc, project: project, doc: doc_in_project)

      ElasticsearchTestHelper.index_document(doc_in_project)
      ElasticsearchTestHelper.index_document(doc_not_in_project)
      ElasticsearchTestHelper.index_project_membership(doc_in_project.id, project.id, project.name)
      ElasticsearchTestHelper.refresh_index
    end

    it 'filters results by project' do
      results = Doc.search_by_elasticsearch('genes', project, nil, 1, 10)

      expect(results.total).to eq(1)
      expect(results.first.id.to_i).to eq(doc_in_project.id)
    end

    it 'returns all matching docs when no project filter' do
      results = Doc.search_by_elasticsearch('genes', nil, nil, 1, 10)

      expect(results.total).to eq(2)
    end
  end

  describe 'Hybrid search (BM25 + vector)', if: ElasticsearchTestHelper.rrf_available? do
    let!(:doc_exact) { create(:doc, body: 'p53 tumor suppressor protein in cancer cells') }
    let!(:doc_semantic) { create(:doc, body: 'TP53 gene mutations and oncogenesis') }
    let!(:doc_unrelated) { create(:doc, body: 'Weather forecast for tomorrow sunny') }

    before do
      # Mock embedding service
      allow(EmbeddingService).to receive(:generate).and_return(sample_embedding)

      # Index with embeddings
      [doc_exact, doc_semantic, doc_unrelated].each do |doc|
        # Generate slightly different embeddings to simulate semantic similarity
        embedding = Array.new(768) { rand(-1.0..1.0) }
        ElasticsearchTestHelper.index_document(doc, embedding: embedding)
      end
      ElasticsearchTestHelper.refresh_index
    end

    it 'performs hybrid search combining BM25 and kNN' do
      results = Doc.hybrid_search('p53 tumor suppressor', page: 1, per: 10)

      expect(results).to be_present
      expect(results.total).to be >= 1
    end

    it 'falls back to BM25 when embedding service fails' do
      allow(EmbeddingService).to receive(:generate).and_return(nil)

      results = Doc.hybrid_search('tumor', page: 1, per: 10)

      expect(results).to be_present
    end
  end

  describe 'Hybrid search fallback (without RRF)', unless: ElasticsearchTestHelper.rrf_available? do
    let!(:doc) { create(:doc, body: 'p53 tumor suppressor protein in cancer cells') }

    before do
      ElasticsearchTestHelper.index_document(doc)
      ElasticsearchTestHelper.refresh_index
    end

    it 'falls back to BM25 when embedding service fails' do
      allow(EmbeddingService).to receive(:generate).and_return(nil)

      results = Doc.hybrid_search('tumor', page: 1, per: 10)

      expect(results).to be_present
    end
  end

  describe 'Document count' do
    before do
      5.times do |i|
        doc = create(:doc, body: "Test document #{i}")
        ElasticsearchTestHelper.index_document(doc)
      end
      ElasticsearchTestHelper.refresh_index
    end

    it 'returns correct document count' do
      count = Doc.es_count

      expect(count).to eq(5)
    end

    it 'returns count filtered by project' do
      project = create(:project)
      doc = Doc.first
      create(:project_doc, project: project, doc: doc)
      ElasticsearchTestHelper.index_project_membership(doc.id, project.id, project.name)
      ElasticsearchTestHelper.refresh_index

      count = Doc.es_count(project: project)

      expect(count).to eq(1)
    end
  end
end
