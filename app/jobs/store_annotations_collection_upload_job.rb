class StoreAnnotationsCollectionUploadJob < ApplicationJob
  queue_as :low_priority

  def perform(project, filepath, options)
    # read the filenames of json files into the array filenames
    filenames, dir_path = read_filenames(filepath)

    # initialize the counter
    if @job
      prepare_progress_record(filenames.length)
    end

    # initialize necessary variables
    @is_sequenced = false
    @longest_processing_time = 0

    annotation_transaction = AnnotationTransaction.new

    (filenames << nil).each_with_index do |jsonfile, i|
      # I found the guard, so I'll end the loop.
      if jsonfile.nil?
        store_docs(project, annotation_transaction.sourcedb_sourceids_index)
        store_annotations(project, annotation_transaction, options)
        break
      end

      annotation_collection = AnnotationCollection.new(jsonfile)

      # Add annotations to transaction.
      annotation_transaction << annotation_collection

      # Save annotations when enough transactions have been stored.
      if annotation_transaction.enough?
        num_sequenced = store_docs(project, annotation_transaction.sourcedb_sourceids_index)
        store_annotations(project, annotation_transaction, options)
        @is_sequenced = true if num_sequenced > 0

        annotation_transaction = AnnotationTransaction.new
      end

      if @job
        @job.update_attribute(:num_dones, i + 1)
        check_suspend_flag
      end
    rescue Exceptions::JobSuspendError
      raise
    rescue StandardError => e
      if @job
        body = Rails.env.development? ? "#{e.backtrace_locations ? e.backtrace_locations[0..2] : 'no backtrace;'} #{e.message[0..250]}" : e.message[0..250]
        @job.add_message sourcedb: annotation_collection&.sourcedb,
                         sourceid: annotation_collection&.sourceid,
                         body: body
      else
        raise ArgumentError, "[#{annotation_collection.sourcedb}:#{annotation_collection.sourceid}] #{e.message}"
      end
    end

    if @is_sequenced
      ActionController::Base.new.expire_fragment('sourcedb_counts')
      ActionController::Base.new.expire_fragment('docs_count')
    end

    File.unlink(filepath)
    FileUtils.rm_rf(dir_path) unless dir_path.nil?
    true
  end

  def job_name
    'Upload annotations'
  end

  private

  def store_annotations(project, annotation_transaction, options)
    messages = project.store_annotations_collection(annotation_transaction.annotation_transaction, options)
    if messages.present?
      if @job
        messages.each do |m|
          @job.add_message m
        end
      else
        raise ArgumentError, messages.collect { |m| "[#{m[:sourcedb]}-#{m[:sourceid]}] #{m[:body]}" }.join("\n")
      end
    end
  end

  def store_docs(project, sourcedb_sourceids_index)
    source_dbs_changed = []
    total_num_sequenced = 0

    sourcedb_sourceids_index.each do |sourcedb, source_ids|
      num_added, num_sequenced, _, messages = project.add_docs(sourcedb, source_ids.to_a)
      source_dbs_changed << sourcedb if num_added > 0
      total_num_sequenced += num_sequenced
      if @job
        messages.each do |message|
          @job.add_message(message.class == Hash ? message : { body: message[0..250] })
        end
      else
        raise messages.join("\n") if @messages.present?
      end
    end

    if source_dbs_changed.present?
      ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
      ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
      source_dbs_changed.each { |sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}") }
    end

    total_num_sequenced
  end

  def read_filenames(filepath)
    dirpath = nil
    filenames = if filepath.end_with?('.json')
                  Dir.glob(filepath)
                else
                  dirpath = File.join('tmp', File.basename(filepath, ".*"))
                  unpack_cmd = "mkdir #{dirpath}; tar -xzf #{filepath} -C #{dirpath}"
                  unpack_success_p = system(unpack_cmd)
                  raise IOError, "Could not unpack the archive file." unless unpack_success_p
                  Dir.glob(File.join(dirpath, '**', '*.json'))
                end.sort
    [filenames, dirpath]
  end
end
