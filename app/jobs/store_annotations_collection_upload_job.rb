require 'fileutils'
include AnnotationsHelper

class StoreAnnotationsCollectionUploadJob < Struct.new(:filepath, :project, :options)
	include StateManagement

  MAX_SIZE_TRANSACTION = 5000

	def perform
    # read the filenames of json files into the array jsonfiles
    dirpath = nil
    jsonfiles = if filepath.end_with?('.json')
      Dir.glob(filepath)
    else
      dirpath = File.join('tmp', File.basename(filepath, ".*"))
      unpack_cmd = "mkdir #{dirpath}; tar -xzf #{filepath} -C #{dirpath}"
      unpack_success_p = system(unpack_cmd)
      raise IOError, "Could not unpack the archive file." unless unpack_success_p
      Dir.glob(File.join(dirpath, '**', '*.json'))
    end.sort

    # check annotation files
    if @job
      @job.update_attribute(:num_items, jsonfiles.length)
      @job.update_attribute(:num_dones, 0)
    end

    @total_num_sequenced = 0

    sourcedb_sourceids_index = Hash.new{|hsh, key| hsh[key] = Set.new}
    annotation_transaction = []
    transaction_size = 0

    jsonfiles.each_with_index do |jsonfile, i|
      json = File.read(jsonfile)
      o =
        begin
          JSON.parse(json, symbolize_names:true)
        rescue => e
          message = "[#{File.basename(jsonfile)}] JSON parse error. Not a valid JSON object."
          if @job
            @job.messages << Message.create({body: "[#{File.basename(jsonfile)}] JSON parse error. Not a valid JSON object."})
          else
            raise ArgumentError, message
          end
          next
        end
      annotation_collection = o.is_a?(Array) ? o : [o]

      annotation_collection.each do |annotations|
        begin
          raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotations[:sourcedb].present? && annotations[:sourceid].present?
          Annotation.normalize!(annotations)

          sourcedb_sourceids_index[annotations[:sourcedb]] << annotations[:sourceid]

          if annotations[:denotations].present?
            annotation_transaction << annotations
            transaction_size += annotations[:denotations].size
          end

          if transaction_size > MAX_SIZE_TRANSACTION
            store(annotation_transaction, sourcedb_sourceids_index)
            if @job
              @job.update_attribute(:num_dones, i + 1)
            end

            annotation_transaction.clear
            transaction_size = 0
            sourcedb_sourceids_index.clear
          end
        rescue => e
          if @job
            @job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message})
          else
            raise ArgumentError, "[#{annotations[:sourcedb]}-#{annotations[:sourceid]}#{annotations[:divid].nil? ? '' : '-' + annotations[:divid]}] #{e.message}"
          end
        end
      end
    end

    store(annotation_transaction, sourcedb_sourceids_index)

    if @total_num_sequenced > 0
      ActionController::Base.new.expire_fragment('sourcedb_counts')
      ActionController::Base.new.expire_fragment('docs_count')
    end

    if @job
      @job.update_attribute(:num_dones, jsonfiles.length)
    end

    File.unlink(filepath)
    FileUtils.rm_rf(dirpath) unless dirpath.nil?
    true
	end

  private

  def store(annotation_transaction, sourcedb_sourceids_index)
    sourcedbs_changed = []

    sourcedb_sourceids_index.each do |sourcedb, sourceids|
      num_added, num_sequenced, num_existed, messages = project.add_docs(sourcedb, sourceids.to_a)
      sourcedbs_changed << sourcedb if num_added > 0
      @total_num_sequenced += num_sequenced
      messages.each do |message|
        @job.messages << (message.class == Hash ? Message.create(message) : Message.create({body: message}))
      end
    end

    messages = project.store_annotations_collection(annotation_transaction, options)
    if messages.present?
      if @job
        messages.each{|m| @job.messages << Message.create(m)}
      else
        msgs = messages.collect{|m| "[#{m[:sourcedb]}-#{m[:sourceid]}#{m[:divid].nil? ? '' : '-' + m[:divid]}] #{m[:body]}"}
        raise ArgumentError, msgs.join("\n")
      end
    end

    unless sourcedbs_changed.empty?
      ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
      ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
      sourcedbs_changed.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
    end
  end
end
