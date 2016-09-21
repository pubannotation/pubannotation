require 'fileutils'
include AnnotationsHelper

class StoreAnnotationsCollectionUploadJob < Struct.new(:filepath, :project, :options)
	include StateManagement

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
    end

    # check annotation files
    @job.update_attribute(:num_items, jsonfiles.length)
    @job.update_attribute(:num_dones, 0)

    sourcedbs = []
    annotation_transaction = []
    transaction_size = 0
    jsonfiles.each_with_index do |jsonfile, i|
      json = File.read(jsonfile)
      begin
        o = JSON.parse(json, symbolize_names:true)
      rescue => e
        @job.messages << Message.create({body: "[#{File.basename(jsonfile)}] " + e.message})
        next
      end
      annotation_collection = o.is_a?(Array) ? o : [o]

      annotation_collection.each do |annotations|
        begin
          raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotations[:sourcedb].present? && annotations[:sourceid].present?
          normalize_annotations!(annotations)
          divs_added = project.add_doc(annotations[:sourcedb], annotations[:sourceid])
          sourcedbs << annotations[:sourcedb] unless divs_added.nil?

          if annotations[:denotations].present?
            annotation_transaction << annotations
            transaction_size += annotations[:denotations].size
          end

          if transaction_size > 1000
            messages = project.store_annotations_collection(annotation_transaction, options)
            messages.each {|m| @job.messages << Message.create(m)} unless messages.nil?
            annotation_transaction = []
            transaction_size = 0
            unless sourcedbs.empty?
              ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
              sourcedbs.uniq.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
              sourcedbs.clear
            end
          end
        rescue => e
          @job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message})
        end
      end
    	@job.update_attribute(:num_dones, i + 1)
    end

    messages = project.store_annotations_collection(annotation_transaction, options)
    messages.each {|m| @job.messages << Message.create(m)} unless messages.nil?
    unless sourcedbs.empty?
      ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
      sourcedbs.uniq.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
    end

    File.unlink(filepath)
    FileUtils.rm_rf(dirpath) unless dirpath.nil?
	end
end
