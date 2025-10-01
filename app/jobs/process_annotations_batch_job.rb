# frozen_string_literal: true

require 'ostruct'

class ProcessAnnotationsBatchJob < ApplicationJob
  queue_as :general  # Different queue to avoid competing with parent job

  def perform(project, annotation_transaction, options, parent_job_id)
    start_time = Time.current
    @parent_job_id = parent_job_id

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
    doc_specs_missing = store_docs(project, doc_specs)
    Rails.logger.info "[#{self.class.name}] store_docs took #{Time.current - store_start}s for #{doc_specs.size} docs"

    # CPU-bound
    # report the missing docs
    doc_specs_missing.group_by {|doc_spec| doc_spec[:sourcedb]}.each do |sourcedb, doc_specs|
      sourceids = doc_specs.map { |doc_spec| doc_spec[:sourceid] }
      parent_job.add_message(
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
    increment_parent_progress(num_failed_annotations) if num_failed_annotations > 0
    transaction_size_remaining = valid_annotations.size

    if valid_annotations.any?
      # CPU: Text alignment processing (only for valid annotations)
      align_start = Time.current
      alignment_messages = process_text_alignment(project, valid_annotations, options)
      Rails.logger.info "[#{self.class.name}] process_text_alignment took #{Time.current - align_start}s for #{valid_annotations.size} annotations"

      # Keep simple message handling to avoid serialization
      alignment_messages.each { |message| parent_job.add_message(message) }
      increment_parent_progress(transaction_size_remaining)
    end

    # Report any docs that need replacement cleanup to parent job
    if Thread.current[:docs_needing_replacement]&.any?
      docs_needing_replacement = Thread.current[:docs_needing_replacement].to_a
      Rails.logger.info "[#{self.class.name}] Reporting #{docs_needing_replacement.size} docs needing replacement cleanup to parent job"

      parent_job.add_message(
        sourcedb: '*',
        sourceid: ['replacement_cleanup'],
        body: "DOCS_NEEDING_REPLACEMENT:#{docs_needing_replacement.join(',')}"
      )
    end

    Rails.logger.info "[#{self.class.name}] Total job time: #{Time.current - start_time}s (#{annotation_transaction.size} annotations)"

  rescue Exceptions::JobSuspendError => e
    Rails.logger.info "[#{self.class.name}] Child job suspended gracefully"
    # Don't log as error - suspension is expected behavior
    # Still increment progress to maintain parent job tracking
    increment_parent_progress(transaction_size_remaining)
    raise e  # Re-raise to maintain suspension behavior
  rescue => e
    message  = "Batch processing error: #{e.class} - #{e.message}"
    message += ": #{e.backtrace}" if e.backtrace

    parent_job.add_message(
      sourcedb: '*',
      sourceid: ['batch_error'],
      body: message
    )
    increment_parent_progress(transaction_size_remaining)
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
      project.instantiate_and_save_annotations_collection(valid_doc_annotations) if valid_doc_annotations.present?

      Rails.logger.info "[#{self.class.name}] Document #{doc_id} processing took #{Time.current - doc_start}s (#{doc_annotations.size} annotations)"
    end

    warnings
  end

  def store_docs(project, doc_specs)
    # doc_specs is already unique
    begin
      num_added, num_sequenced, doc_specs_missing, messages = project.add_docs_from_array(doc_specs)
    # rescue => e
    #   raise e
    end

    messages.each do |message|
      parent_job.add_message(message)
    end

    doc_specs_missing
  end

  def increment_parent_progress(batch_size)
    parent_job.increment!(:num_dones, batch_size)
  end

  def batch_add_messages(messages)
    return unless messages&.any?

    # Add messages in batches to reduce database round trips
    messages.each_slice(10) do |message_batch|
      message_batch.each { |message| parent_job.add_message(message) }
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
    @parent_job ||= Job.find(@parent_job_id)
  end

  def check_suspend_flag
    suspend_file = Rails.root.join('tmp', "suspend_job_#{@parent_job_id}")
    if File.exist?(suspend_file)
      Rails.logger.info "[#{self.class.name}] Job suspended via file: #{suspend_file}"
      progress_info = @current_batch_index ? "at batch #{@current_batch_index}/#{@total_batches}" : "during initialization"
      raise Exceptions::JobSuspendError, "Job suspended #{progress_info} - processing can be resumed later."
    end
  end

end
