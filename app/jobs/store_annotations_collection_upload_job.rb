class StoreAnnotationsCollectionUploadJob < ApplicationJob
  queue_as :low_priority

  MAX_SIZE_TRANSACTION = 5000

  def perform(project, filepath, options)
    # read the filenames of json files into the array filenames
    filenames, dir_path = read_filenames(filepath)

    # initialize the counter
    if @job
      prepare_progress_record(filenames.length)
    end

    # initialize necessary variables
    @total_num_sequenced = 0
    @longest_processing_time = 0

    annotation_transaction = []
    transaction_size = 0
    sourcedb_sourceids_index = Hash.new(Set.new)

    (filenames << nil).each_with_index do |jsonfile, i|
      unless jsonfile.nil?
        annotation_collection, sourcedb, sourceid = read_annotation(jsonfile)

        count_denotations = annotation_collection.map { _1[:denotations].present? ? _1[:denotations].size : 0 }
                                                 .sum

        next unless count_denotations > 0
      end

      if jsonfile.nil? || (transaction_size + count_denotations) > MAX_SIZE_TRANSACTION
        begin
          source_dbs_changed = store_docs(project, sourcedb_sourceids_index)
          store(annotation_transaction, sourcedb_sourceids_index, project, options)

          unless source_dbs_changed.empty?
            ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
            ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
            source_dbs_changed.each { |sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}") }
          end
        ensure
          annotation_transaction.clear
          transaction_size = 0
          sourcedb_sourceids_index.clear
        end
      end

      unless jsonfile.nil?
        annotation_transaction << annotation_collection
        transaction_size += count_denotations
        sourcedb_sourceids_index[sourcedb] << sourceid
        if @job
          @job.update_attribute(:num_dones, i + 1)
          check_suspend_flag
        end
      end

    rescue ActiveRecord::ActiveRecordError => e
      if @job
        @job.add_message body: e.message[0..250]
      else
        raise e
      end
    rescue Exceptions::JobSuspendError
      raise
    rescue StandardError => e
      if @job
        @job.add_message sourcedb: sourcedb,
                         sourceid: sourceid,
                         body: e.message[0..250]
      else
        raise ArgumentError, "[#{sourcedb}:#{sourceid}] #{e.message}"
      end
    end

    if @total_num_sequenced > 0
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

  def store(annotation_transaction, sourcedb_sourceids_index, project, options)
    timer_start = Time.now
    messages = project.store_annotations_collection(annotation_transaction, options)
    ptime = Time.now - timer_start
    if options[:debug].present? && ptime > @longest_processing_time
      doc_specs = sourcedb_sourceids_index.collect { |sourcedb, sourceids| "#{sourcedb}-#{sourceids.to_a.join(",")}" }.join(", ")
      @job.add_message body: "Longest processing time so far (#{ptime}): #{doc_specs}"
      @longest_processing_time = ptime
    end

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

    sourcedb_sourceids_index.each do |sourcedb, source_ids|
      num_added, num_sequenced, _, messages = project.add_docs(sourcedb, source_ids.to_a)
      source_dbs_changed << sourcedb if num_added > 0
      @total_num_sequenced += num_sequenced
      if @job
        messages.each do |message|
          @job.add_message(message.class == Hash ? message : { body: message[0..250] })
        end
      else
        raise messages.join("\n") if @messages.present?
      end
    end

    source_dbs_changed
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

  def read_annotation(filename)
    json = File.read(filename)
    o = begin
          JSON.parse(json, symbolize_names: true)
        rescue => e
          raise "[#{File.basename(filename)}] JSON parse error. Not a valid JSON object."
        end

    # To return the annotation in an array
    annotation_collection = o.is_a?(Array) ? o : [o]

    # validation and normalization
    sourcedb, sourceid = nil, nil
    annotation_collection.each do |annotations|
      raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotations[:sourcedb].present? && annotations[:sourceid].present?
      if sourcedb.nil?
        sourcedb = annotations[:sourcedb]
        sourceid = annotations[:sourceid]
      elsif (annotations[:sourcedb] != sourcedb) || (annotations[:sourceid] != sourceid)
        raise ArgumentError, "One json file has to include annotations to the same document."
      end
      Annotation.normalize!(annotations)
    end

    [annotation_collection, sourcedb, sourceid]
  end
end
