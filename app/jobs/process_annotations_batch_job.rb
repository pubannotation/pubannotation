# frozen_string_literal: true

require 'ostruct'

class ProcessAnnotationsBatchJob < ApplicationJob
  queue_as :general  # Different queue to avoid competing with parent job

  def perform(project, annotation_transaction, options, parent_job_id, tracking_id)
    start_time = Time.current
    @parent_job_id = parent_job_id
    @tracking_id = tracking_id

    # Load tracking record and mark as running (only if tracking is enabled)
    if @tracking_id.present?
      @tracking = BatchJobTracking.find_by(id: @tracking_id)

      if @tracking.nil?
        Rails.logger.warn "[#{self.class.name}] Tracking record #{@tracking_id} not found - parent job already finished. Exiting."
        return
      end

      # If tracking was already marked as failed/crashed (stale pending detection), don't process
      if @tracking.status != 'pending'
        Rails.logger.warn "[#{self.class.name}] Tracking record #{@tracking_id} already in status '#{@tracking.status}' - skipping execution."
        return
      end

      @tracking.mark_running!
    else
      # No tracking (immediate execution)
      @tracking = nil
      Rails.logger.info "[#{self.class.name}] Running without tracking (immediate execution)"
    end

    # Set thread-local variable to enable batch processing optimizations
    Thread.current[:skip_annotation_callbacks] = true
    Rails.logger.info "[#{self.class.name}] Set skip_annotation_callbacks=#{Thread.current[:skip_annotation_callbacks]} for batch processing"

    check_suspend_flag

    transaction_size_remaining = annotation_transaction.size

    # CPU-bound
    doc_specs = annotation_transaction.map do |annotation|
      {sourcedb: annotation[:sourcedb], sourceid: annotation[:sourceid]}
    end.uniq { |id| [id[:sourcedb], id[:sourceid]] }

    # Skip pre-caching to avoid serialization bottleneck - use individual lookups
    # cache_doc_ids(doc_specs)

    # I/O, network-bound
    store_start = Time.current
    doc_specs_missing, doc_specs_personalized = store_docs(project, doc_specs)
    Rails.logger.info "[#{self.class.name}] store_docs took #{Time.current - store_start}s for #{doc_specs.size} docs"

    # Normalize annotation sourcedbs to match actual documents (personalized or not)
    # Use the personalized mapping from store_docs to avoid redundant lookups
    if doc_specs_personalized.present?
      # Cache personalized sourcedb strings to avoid repeated string concatenation
      personalized_sourcedb_cache = {}

      annotation_transaction.each do |annotation|
        sourcedb = annotation[:sourcedb]
        sourceid = annotation[:sourceid]

        # If this sourcedb+sourceid pair has a personalized version, update it
        # Note: doc_specs_personalized values are Sets for O(1) lookup
        if doc_specs_personalized[sourcedb]&.include?(sourceid)
          personalized_sourcedb_cache[sourcedb] ||= Doc.personalize_sourcedb(sourcedb, project.user.username)
          annotation[:sourcedb] = personalized_sourcedb_cache[sourcedb] if personalized_sourcedb_cache[sourcedb]
        end
      end
    end

    # CPU-bound
    # report the missing docs
    doc_specs_missing.group_by {|doc_spec| doc_spec[:sourcedb]}.each do |sourcedb, doc_specs|
      sourceids = doc_specs.map { |doc_spec| doc_spec[:sourceid] }
      parent_job&.add_message(
        sourcedb: sourcedb,
        sourceid: sourceids,
        body: "Could not get the document from #{sourcedb}"
      )
    end

    doc_descriptors_missing = doc_specs_missing.map {|doc_spec| "#{doc_spec[:sourcedb]}:#{doc_spec[:sourceid]}"}.to_set
    valid_annotations = annotation_transaction.reject do |annotation|
      doc_spec = "#{annotation[:sourcedb]}:#{annotation[:sourceid]}"
      doc_descriptors_missing.include?(doc_spec)
    end

    num_failed_annotations = transaction_size_remaining - valid_annotations.size
    # Note: No need to increment parent progress - parent tracks via tracking table
    transaction_size_remaining = valid_annotations.size

    if valid_annotations.any?
      # CPU: Text alignment processing (only for valid annotations)
      align_start = Time.current
      alignment_messages, doc_deltas = process_text_alignment(project, valid_annotations, options)
      Rails.logger.info "[#{self.class.name}] process_text_alignment took #{Time.current - align_start}s for #{valid_annotations.size} annotations"

      # Keep simple message handling to avoid serialization
      alignment_messages.each { |message| parent_job&.add_message(message) }

      # Bulk update counters for all documents processed in this batch
      # Strategy: Incremental updates for docs and project_docs, bulk update for project at end
      if doc_deltas.any?
        counter_start = Time.current

        # Extract new_counts for project_docs (only cares about new annotations)
        project_docs_deltas = doc_deltas.transform_values { |v| v[:new_counts] }

        # Calculate net deltas for docs (new - old, for cross-project aggregates)
        docs_net_deltas = doc_deltas.transform_values do |v|
          {
            denotations: v[:new_counts][:denotations] - v[:old_counts][:denotations],
            blocks: v[:new_counts][:blocks] - v[:old_counts][:blocks],
            relations: v[:new_counts][:relations] - v[:old_counts][:relations]
          }
        end

        ActiveRecord::Base.transaction do
          # Update project_docs (per-project counts) - use new_counts
          ProjectDoc.bulk_increment_counts_for_batch(
            project_id: project.id,
            doc_deltas: project_docs_deltas,
            mode: options[:mode]
          )

          # Update docs (cross-project aggregates) - use net deltas
          Doc.bulk_increment_counts_for_batch(doc_deltas: docs_net_deltas)

          # Skip project-level counters here - will be updated from database at end
          # in StoreAnnotationsCollectionUploadJob#update_final_project_stats
        end

        Rails.logger.info "[#{self.class.name}] bulk_increment_counters took #{Time.current - counter_start}s for #{doc_deltas.size} docs"
      end
    end

    Rails.logger.info "[#{self.class.name}] Total job time: #{Time.current - start_time}s (#{annotation_transaction.size} annotations)"

    # Mark tracking as completed (if tracking is enabled)
    @tracking&.mark_completed!

  rescue Exceptions::JobSuspendError => e
    Rails.logger.info "[#{self.class.name}] Child job suspended gracefully"
    # Mark as failed with suspension message
    @tracking&.update!(
      status: 'failed',
      error_message: 'Job suspended by user request',
      completed_at: Time.current
    )
    raise e  # Re-raise to maintain suspension behavior
  rescue => e
    Rails.logger.error "[#{self.class.name}] Batch processing error: #{e.class} - #{e.message}"

    message  = "Batch processing error: #{e.class} - #{e.message}"
    message += "\n#{e.backtrace&.first(10)&.join("\n")}" if e.backtrace

    parent_job&.add_message(
      sourcedb: '*',
      sourceid: ['batch_error'],
      body: message
    )

    # Mark tracking as failed
    @tracking&.mark_failed!(e)

    raise  # Re-raise to allow Sidekiq to handle retry logic
  ensure
    # Clear thread-local variable
    Thread.current[:skip_annotation_callbacks] = nil
  end

  def job_name
    'Process annotations batch'
  end

  private

  def process_text_alignment(project, annotations, options)
    warnings = []
    doc_deltas = {}  # Collect annotation deltas per document for bulk counter update

    # Group annotations by document
    annotations_by_doc = annotations.group_by { |ann| "#{ann[:sourcedb]}:#{ann[:sourceid]}" }

    annotations_by_doc.each do |doc_id, doc_annotations|
      doc_start = Time.current

      sourcedb, sourceid = doc_id.split(':', 2)
      doc = project.docs.find_by(sourcedb: sourcedb, sourceid: sourceid)

      next unless doc # Skip if document not found

      # Get reference text for alignment
      ref_text = doc&.original_body || doc.body

      # Filter annotations that have denotations or blocks
      annotations_with_content = doc_annotations.select { |ann| ann[:denotations].present? || ann[:blocks].present? }
      next if annotations_with_content.empty?

      # Perform text alignment
      annotations_with_content.each do |annotation|
        begin
          # Create aligner and perform alignment
          aligner = Aligners.new(ref_text, [annotation])
          aligned_annotation = aligner.align_all(options).first

          if aligned_annotation.error_message
            raise "[#{annotation[:sourcedb]}:#{annotation[:sourceid]}] #{aligned_annotation.error_message}"
          end

          # Update annotation with aligned results
          annotation.merge!({
            text: ref_text,
            denotations: aligned_annotation.denotations.map(&:dup),
            blocks: aligned_annotation.blocks.map(&:dup)
          })
          annotation.delete_if { |_, v| !v.present? }

          # Check for lost annotations and add warnings
          if aligned_annotation.lost_annotations.present?
            warnings << {
              sourcedb: annotation[:sourcedb],
              sourceid: annotation[:sourceid],
              body: "Alignment failed. Invalid denotations found after transformation"
            }
          end
        rescue => e
          warnings << {
            sourcedb: annotation[:sourcedb],
            sourceid: annotation[:sourceid],
            body: "Text alignment error: #{e.message}"
          }
        end
      end

      # For replace mode, capture old counts before deletion (needed for docs table net delta)
      old_counts = if options[:mode] == 'replace'
        {
          denotations: project.denotations.where(doc_id: doc.id).count,
          blocks: project.blocks.where(doc_id: doc.id).count,
          relations: project.relations.where(doc_id: doc.id).count
        }
      else
        { denotations: 0, blocks: 0, relations: 0 }
      end

      # Apply project pretreatment and save annotations (with batch processing flag)
      batch_options = options.merge(batch_processing: true)
      project.pretreatment_according_to(batch_options, doc, doc_annotations)

      # Validate annotations and collect warnings
      valid_doc_annotations = []
      doc_annotations.each do |annotation|
        dangling_references = TextAlign::DanglingReferenceFinder.call(
          annotation[:denotations] || [],
          annotation[:blocks] || [],
          annotation[:relations] || [],
          annotation[:attributes] || []
        )
        if dangling_references.present?
          warnings << {
            sourcedb: annotation[:sourcedb],
            sourceid: annotation[:sourceid],
            body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join(', ')}."
          }
        else
          valid_doc_annotations << annotation
        end
      end

      # Save valid annotations
      if valid_doc_annotations.present?
        project.instantiate_and_save_annotations_collection(valid_doc_annotations)

        # Collect deltas for bulk counter update
        # For docs table (cross-project): need net delta (new - old)
        # For project_docs table (per-project): old counts don't matter (deleted first in replace mode)
        new_counts = {
          denotations: valid_doc_annotations.sum { |ann| (ann[:denotations] || []).size },
          blocks: valid_doc_annotations.sum { |ann| (ann[:blocks] || []).size },
          relations: valid_doc_annotations.sum { |ann| (ann[:relations] || []).size }
        }

        doc_deltas[doc.id] = {
          new_counts: new_counts,
          old_counts: old_counts
        }
      end

      Rails.logger.info "[#{self.class.name}] Document #{doc_id} processing took #{Time.current - doc_start}s (#{doc_annotations.size} annotations)"
    end

    # Return both warnings and doc_deltas for caller to process
    [warnings, doc_deltas]
  end

  def store_docs(project, doc_specs)
    # doc_specs is already unique
    begin
      num_added, num_sequenced, doc_specs_missing, messages, doc_specs_personalized = project.add_docs_from_array(doc_specs, batch_processing: true)
    # rescue => e
    #   raise e
    end

    messages.each do |message|
      parent_job&.add_message(message)
    end

    [doc_specs_missing, doc_specs_personalized]
  end

  def batch_add_messages(messages)
    return unless messages&.any?

    # Add messages in batches to reduce database round trips
    messages.each_slice(10) do |message_batch|
      message_batch.each { |message| parent_job&.add_message(message) }
    end
  end

  def cache_doc_ids(doc_specs)
    @doc_id_cache = {}
    return unless doc_specs.any?

    # Single batch query to get all doc IDs
    doc_specs.each_slice(50) do |batch_specs|
      conditions = batch_specs.map { "(sourcedb = ? AND sourceid = ?)" }.join(' OR ')
      params = batch_specs.map { |spec| [spec[:sourcedb], spec[:sourceid]] }.flatten

      Doc.where(conditions, *params)
         .pluck(:sourcedb, :sourceid, :id)
         .each { |sourcedb, sourceid, id| @doc_id_cache["#{sourcedb}:#{sourceid}"] = id }
    end

    Rails.logger.info "[#{self.class.name}] Cached #{@doc_id_cache.size} doc IDs"

    # Make cache available to other methods via thread-local variable
    Thread.current[:doc_id_cache] = @doc_id_cache
  end

  def parent_job
    return nil unless @parent_job_id.present?
    @parent_job ||= Job.find(@parent_job_id)
  end

  def check_suspend_flag
    return unless @parent_job_id.present?  # Skip suspension check for immediate execution

    suspend_file = Rails.root.join('tmp', "suspend_job_#{@parent_job_id}")
    if File.exist?(suspend_file)
      Rails.logger.info "[#{self.class.name}] Job suspended via file: #{suspend_file}"
      progress_info = @current_batch_index ? "at batch #{@current_batch_index}/#{@total_batches}" : "during initialization"
      raise Exceptions::JobSuspendError, "Job suspended #{progress_info} - processing can be resumed later."
    end
  end

end
