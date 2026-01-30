# frozen_string_literal: true

# Elasticsearch 8.x Management Tasks
#
# Usage:
#   rake elasticsearch:status                    # Show index status
#   rake elasticsearch:create_index[1]           # Create index version 1
#   rake elasticsearch:delete_index[1]           # Delete index version 1
#   rake elasticsearch:full_reindex              # Full reindex from PostgreSQL
#   rake elasticsearch:switch_alias[,1]          # Switch alias to version 1
#   rake elasticsearch:verify_sync               # Verify sync between PG and ES
#   rake elasticsearch:repair_sync               # Verify and repair sync
#   rake elasticsearch:generate_embeddings       # Generate embeddings for all docs
#   rake elasticsearch:process_queue             # Process pending queue items
#   rake elasticsearch:clear_queue               # Clear the index queue

namespace :elasticsearch do
  desc 'Show Elasticsearch index status'
  task status: :environment do
    manager = Elasticsearch::IndexManager.new

    puts "\n=== Elasticsearch Status ==="
    puts "URL: #{Elasticsearch::Config.url}"

    # Cluster health
    begin
      health = manager.cluster_health
      puts "\nCluster Health:"
      puts "  Status: #{health['status']}"
      puts "  Nodes: #{health['number_of_nodes']}"
      puts "  Active Shards: #{health['active_shards']}"
    rescue => e
      puts "\nCluster Health: ERROR - #{e.message}"
    end

    # Current index info
    puts "\nIndex Alias: #{ELASTICSEARCH_INDEX_ALIAS}"
    current = manager.current_index
    if current
      puts "Current Index: #{current} (version #{manager.current_version})"
      stats = manager.index_stats
      puts "  Documents: #{stats[:docs_count]}"
      puts "  Size: #{stats[:store_size_human]}"
    else
      puts "Current Index: (no index configured)"
    end

    # Queue status
    queue_size = Elasticsearch::IndexQueue.queue_size
    puts "\nIndex Queue Size: #{queue_size}"

    # PostgreSQL counts for comparison
    puts "\nPostgreSQL Counts:"
    puts "  Documents: #{Doc.count}"
    puts "  Project Memberships: #{ProjectDoc.count}"

    puts "\n"
  end

  desc 'Create a new Elasticsearch index (version required)'
  task :create_index, [:version] => :environment do |_t, args|
    version = args[:version]&.to_i
    raise "Version required: rake elasticsearch:create_index[VERSION]" unless version

    puts "Creating index version #{version}..."
    manager = Elasticsearch::IndexManager.new
    result = manager.create_index(version: version)

    if result[:existing]
      puts "Index already exists."
    else
      puts "Index created successfully."
    end

    stats = manager.index_stats(version: version)
    puts "Index stats: #{stats.inspect}"
  end

  desc 'Delete an Elasticsearch index (version required)'
  task :delete_index, [:version] => :environment do |_t, args|
    version = args[:version]&.to_i
    raise "Version required: rake elasticsearch:delete_index[VERSION]" unless version

    manager = Elasticsearch::IndexManager.new
    index_name = Elasticsearch::Config.index_name(version)

    print "Are you sure you want to delete index #{index_name}? (yes/no): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == 'yes'
      puts "Deleting index version #{version}..."
      manager.delete_index(version: version)
      puts "Index deleted."
    else
      puts "Cancelled."
    end
  end

  desc 'Full reindex from PostgreSQL to Elasticsearch'
  task :full_reindex, [:version] => :environment do |_t, args|
    version = args[:version]&.to_i
    manager = Elasticsearch::IndexManager.new

    # Determine version
    if version.nil?
      current_version = manager.current_version
      version = current_version ? current_version + 1 : 1
      puts "No version specified, using version #{version}"
    end

    puts "Starting full reindex to version #{version}..."
    puts "This will:"
    puts "  1. Create index version #{version}"
    puts "  2. Index all documents from PostgreSQL"
    puts "  3. Index all project memberships"
    puts "  4. Switch alias to new index"
    puts ""

    print "Continue? (yes/no): "
    confirmation = STDIN.gets.chomp

    unless confirmation.downcase == 'yes'
      puts "Cancelled."
      exit
    end

    # Run migration job synchronously
    puts "\nStarting migration..."
    start_time = Time.current

    ElasticsearchMigrationJob.perform_now(
      version: version,
      include_memberships: true,
      switch_alias: true
    )

    elapsed = Time.current - start_time
    puts "\nMigration completed in #{elapsed.round(1)} seconds"

    # Show final stats
    stats = manager.index_stats(version: version)
    puts "Final index stats:"
    puts "  Documents: #{stats[:docs_count]}"
    puts "  Size: #{stats[:store_size_human]}"
  end

  desc 'Switch alias to a specific index version'
  task :switch_alias, [:from_version, :to_version] => :environment do |_t, args|
    to_version = args[:to_version]&.to_i
    raise "Version required: rake elasticsearch:switch_alias[,VERSION]" unless to_version

    manager = Elasticsearch::IndexManager.new
    current = manager.current_index

    puts "Current alias points to: #{current || '(none)'}"
    puts "Will switch to: #{Elasticsearch::Config.index_name(to_version)}"

    print "Continue? (yes/no): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == 'yes'
      manager.switch_alias(to_version: to_version)
      puts "Alias switched successfully."
    else
      puts "Cancelled."
    end
  end

  desc 'Verify sync between PostgreSQL and Elasticsearch'
  task verify_sync: :environment do
    puts "Verifying sync between PostgreSQL and Elasticsearch..."
    ElasticsearchSyncJob.perform_now(repair: false)
    puts "Verification complete. Check logs for details."
  end

  desc 'Verify and repair sync between PostgreSQL and Elasticsearch'
  task repair_sync: :environment do
    puts "Verifying and repairing sync..."
    ElasticsearchSyncJob.perform_now(repair: true)
    puts "Sync repair complete. Check logs for details."
  end

  desc 'Generate embeddings for all documents'
  task :generate_embeddings, [:project_id] => :environment do |_t, args|
    project_id = args[:project_id].presence&.to_i

    # Check if embedding service is available
    unless EmbeddingService.available?
      puts "ERROR: Embedding service not available at #{EmbeddingService::BASE_URL}"
      puts "Please ensure the embedding server is running."
      exit 1
    end

    if project_id
      project = Project.find_by(id: project_id)
      raise "Project not found: #{project_id}" unless project

      puts "Generating embeddings for project: #{project.name} (#{project.docs.count} documents)..."
      GenerateEmbeddingsJob.perform_now(project_id: project_id)
    else
      total = Doc.count
      puts "Generating embeddings for #{total} documents..."
      puts ""
      GenerateEmbeddingsJob.perform_now
    end

    # Show current embedding count
    begin
      stats = ELASTICSEARCH_CLIENT.indices.stats(index: ELASTICSEARCH_INDEX_ALIAS)
      count = stats.dig('_all', 'primaries', 'dense_vector', 'value_count') || 0
      puts "\nEmbeddings in index: #{count}"
    rescue => e
      puts "Could not get embedding count: #{e.message}"
    end

    puts "Embedding generation complete."
  end

  desc 'Process pending items in the index queue'
  task process_queue: :environment do
    queue_size = Elasticsearch::IndexQueue.queue_size
    puts "Queue size: #{queue_size}"

    if queue_size == 0
      puts "Queue is empty, nothing to process."
      exit
    end

    puts "Processing queue..."
    start_time = Time.current
    processed = Elasticsearch::IndexQueue.process_all
    elapsed = Time.current - start_time

    puts "Processed #{processed} operations in #{elapsed.round(1)} seconds"
    puts "Rate: #{(processed / elapsed).round(1)} ops/sec" if elapsed > 0
  end

  desc 'Clear the index queue (use with caution)'
  task clear_queue: :environment do
    queue_size = Elasticsearch::IndexQueue.queue_size

    if queue_size == 0
      puts "Queue is already empty."
      exit
    end

    print "Clear #{queue_size} pending operations? (yes/no): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == 'yes'
      Elasticsearch::IndexQueue.clear
      puts "Queue cleared."
    else
      puts "Cancelled."
    end
  end

  desc 'Index a specific document'
  task :index_doc, [:doc_id] => :environment do |_t, args|
    doc_id = args[:doc_id]&.to_i
    raise "Doc ID required: rake elasticsearch:index_doc[DOC_ID]" unless doc_id

    doc = Doc.find_by(id: doc_id)
    raise "Document not found: #{doc_id}" unless doc

    puts "Indexing document #{doc_id} (#{doc.sourcedb}:#{doc.sourceid})..."
    doc.index_to_es!
    puts "Done."
  end

  desc 'Run a test search'
  task :test_search, [:query] => :environment do |_t, args|
    query = args[:query] || 'cancer'

    puts "Searching for: #{query}"
    puts ""

    results = Doc.search_by_elasticsearch(query, nil, nil, 1, 5)

    puts "Total results: #{results.total}"
    puts "Showing top 5:"
    puts ""

    results.each_with_index do |result, idx|
      puts "#{idx + 1}. #{result.sourcedb}:#{result.sourceid} (score: #{result.score&.round(3)})"
      if result.highlight.body.any?
        puts "   Highlight: #{result.highlight.body.first[0..200]}..."
      end
      puts ""
    end
  end
end
