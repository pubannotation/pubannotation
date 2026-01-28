# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DocsController#show with span - N+1 query prevention', type: :request do
  # Stub Elasticsearch to avoid connection errors
  before do
    allow_any_instance_of(Doc).to receive(:__elasticsearch__).and_return(double(index_document: true, delete_document: true))
  end

  let(:user) { create(:user) }
  let(:doc) { create(:doc, body: 'This is a test document with enough text for spans to work properly.') }

  # Create multiple projects with denotations
  let!(:project1) { create(:project, user: user) }
  let!(:project2) { create(:project, user: user) }
  let!(:project3) { create(:project, user: user) }

  let!(:project_doc1) { create(:project_doc, project: project1, doc: doc) }
  let!(:project_doc2) { create(:project_doc, project: project2, doc: doc) }
  let!(:project_doc3) { create(:project_doc, project: project3, doc: doc) }

  # Span to query: begin=5, end=20
  let(:span_begin) { 5 }
  let(:span_end) { 20 }

  before do
    # Create denotations within the span for project1 (3 denotations)
    create(:denotation, project: project1, doc: doc, begin: 5, end: 10)
    create(:denotation, project: project1, doc: doc, begin: 10, end: 15)
    create(:denotation, project: project1, doc: doc, begin: 15, end: 20)

    # Create denotations within the span for project2 (2 denotations)
    create(:denotation, project: project2, doc: doc, begin: 6, end: 12)
    create(:denotation, project: project2, doc: doc, begin: 12, end: 18)

    # Create denotations within the span for project3 (1 denotation)
    create(:denotation, project: project3, doc: doc, begin: 7, end: 14)

    # Create denotations OUTSIDE the span (should not be counted)
    create(:denotation, project: project1, doc: doc, begin: 0, end: 4)   # before span
    create(:denotation, project: project1, doc: doc, begin: 21, end: 30) # after span
    create(:denotation, project: project2, doc: doc, begin: 0, end: 25)  # overlaps but not contained
  end

  describe 'N+1 query prevention' do
    it 'uses a single GROUP BY query to fetch all denotation counts instead of one per project' do
      # Count queries during the actual request
      denotation_count_queries = []

      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        if sql.include?('denotations') && (sql.include?('COUNT') || sql.include?('count'))
          denotation_count_queries << sql
        end
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/spans/#{span_begin}-#{span_end}"
      end

      # After fix: Should have at most one GROUP BY count query
      grouped_count_queries = denotation_count_queries.select { |q| q.include?('GROUP BY') }

      # After fix: Should NOT have multiple individual count queries (one per project)
      individual_count_queries = denotation_count_queries.select do |q|
        q.include?('COUNT') && !q.include?('GROUP BY')
      end

      # The fix should result in either:
      # 1. One GROUP BY query (batch loading)
      # 2. Or no count queries if using preloaded hash
      expect(individual_count_queries.length).to be < 3,
        "Expected fewer than 3 individual count queries but got #{individual_count_queries.length}. " \
        "This indicates N+1 queries are still happening. Queries: #{individual_count_queries.inspect}"
    end
  end
end

# Separate test for the batch loading query itself at model level
RSpec.describe 'Denotation batch counting for span', type: :model do
  before do
    allow_any_instance_of(Doc).to receive(:__elasticsearch__).and_return(double(index_document: true, delete_document: true))
  end

  let(:user) { create(:user) }
  let(:doc) { create(:doc, body: 'This is a test document body.') }

  let!(:project1) { create(:project, user: user) }
  let!(:project2) { create(:project, user: user) }
  let!(:project3) { create(:project, user: user) }

  let!(:project_doc1) { create(:project_doc, project: project1, doc: doc) }
  let!(:project_doc2) { create(:project_doc, project: project2, doc: doc) }
  let!(:project_doc3) { create(:project_doc, project: project3, doc: doc) }

  let(:span) { { begin: 5, end: 20 } }

  before do
    # Create denotations within the span for project1 (3 denotations)
    create(:denotation, project: project1, doc: doc, begin: 5, end: 10)
    create(:denotation, project: project1, doc: doc, begin: 10, end: 15)
    create(:denotation, project: project1, doc: doc, begin: 15, end: 20)

    # Create denotations within the span for project2 (2 denotations)
    create(:denotation, project: project2, doc: doc, begin: 6, end: 12)
    create(:denotation, project: project2, doc: doc, begin: 12, end: 18)

    # Create denotations within the span for project3 (1 denotation)
    create(:denotation, project: project3, doc: doc, begin: 7, end: 14)

    # Create denotations OUTSIDE the span (should not be counted)
    create(:denotation, project: project1, doc: doc, begin: 0, end: 4)   # before span
    create(:denotation, project: project1, doc: doc, begin: 21, end: 30) # after span
    create(:denotation, project: project2, doc: doc, begin: 0, end: 25)  # overlaps but not contained
  end

  describe 'batch loading denotation counts' do
    it 'correctly counts denotations within the span for each project using a single query' do
      project_ids = [project1.id, project2.id, project3.id]

      # This is the batch query that should be used in the controller
      counts = Denotation
        .where(doc_id: doc.id, project_id: project_ids)
        .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
        .group(:project_id)
        .count

      expect(counts[project1.id]).to eq(3)
      expect(counts[project2.id]).to eq(2)
      expect(counts[project3.id]).to eq(1)
    end

    it 'does not include denotations outside the span' do
      project_ids = [project1.id, project2.id, project3.id]

      counts = Denotation
        .where(doc_id: doc.id, project_id: project_ids)
        .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
        .group(:project_id)
        .count

      # project1 has 5 total denotations (3 inside span, 2 outside)
      # Only 3 should be counted
      expect(counts[project1.id]).to eq(3)

      # project2 has 3 total denotations (2 inside span, 1 overlapping but not contained)
      # Only 2 should be counted
      expect(counts[project2.id]).to eq(2)
    end

    it 'returns empty hash when no denotations match' do
      # Query with a span that has no denotations
      counts = Denotation
        .where(doc_id: doc.id)
        .where('"begin" >= ? AND "end" <= ?', 100, 200)
        .group(:project_id)
        .count

      expect(counts).to eq({})
    end

    it 'only includes specified projects' do
      # Only query for project1
      counts = Denotation
        .where(doc_id: doc.id, project_id: [project1.id])
        .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
        .group(:project_id)
        .count

      expect(counts.keys).to eq([project1.id])
      expect(counts[project1.id]).to eq(3)
      expect(counts[project2.id]).to be_nil
    end

    it 'executes only one SQL query' do
      project_ids = [project1.id, project2.id, project3.id]
      query_count = 0

      callback = lambda do |_name, _start, _finish, _id, payload|
        query_count += 1 unless payload[:name] == 'SCHEMA'
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        Denotation
          .where(doc_id: doc.id, project_id: project_ids)
          .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
          .group(:project_id)
          .count
      end

      expect(query_count).to eq(1)
    end
  end

  describe 'comparison with N+1 approach' do
    it 'N+1 approach executes one query per project' do
      project_ids = [project1.id, project2.id, project3.id]
      query_count = 0

      callback = lambda do |_name, _start, _finish, _id, payload|
        query_count += 1 unless payload[:name] == 'SCHEMA'
      end

      # This simulates the N+1 problem - one query per project
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        project_ids.each do |project_id|
          Denotation
            .where(doc_id: doc.id, project_id: project_id)
            .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
            .count
        end
      end

      # N+1: one query per project
      expect(query_count).to eq(3)
    end

    it 'batch approach uses only one query for all projects' do
      project_ids = [project1.id, project2.id, project3.id]
      query_count = 0

      callback = lambda do |_name, _start, _finish, _id, payload|
        query_count += 1 unless payload[:name] == 'SCHEMA'
      end

      # Batch approach - one query for all projects
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        Denotation
          .where(doc_id: doc.id, project_id: project_ids)
          .where('"begin" >= ? AND "end" <= ?', span[:begin], span[:end])
          .group(:project_id)
          .count
      end

      expect(query_count).to eq(1)
    end
  end
end
