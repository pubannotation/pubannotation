require 'fileutils'

class UploadDocsJob < Struct.new(:filepath, :project, :options)
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
    end.sort

    # check annotation files
    if @job
      @job.update_attribute(:num_items, jsonfiles.length)
      @job.update_attribute(:num_dones, 0)
    end

    username = project.user
    mode = options[:mode]
    num_updated = 0
    sourcedbs_added = Set[]
    jsonfiles.each_with_index do |jsonfile, i|
      begin
        json = File.read(jsonfile)
        doc_hash = JSON.parse(json, symbolize_names:true)
        doc_hash = Doc.prepare_creation(doc_hash, username)
        same_docs = Doc.where(sourcedb: doc_hash[:sourcedb], sourceid: doc_hash[:sourceid])

        same_doc = if same_docs.count == 1
          same_docs.first
        elsif same_docs.count > 1
          raise ArgumentError, "Documents with multiple divs cannot be updated."
        else
          nil
        end

        if same_doc.present?
          same_doc.revise(doc_hash[:body]) if mode == :update
          num_updated+= 1
        else
          doc = Doc.new(doc_hash)
          doc.save!
          doc.projects << project
          sourcedbs_added << doc_hash[:sourcedb]
        end
      rescue => e
        message = "[#{File.basename(jsonfile)}] #{e.message}"
        if @job
          @job.messages << Message.create({body: message})
        else
          raise ArgumentError, message
        end
      ensure
        if @job
          @job.update_attribute(:num_dones, i + 1)
        end
      end
    end

    if @job
      @job.messages << Message.create({body: "#{num_updated} docs were #{mode == :update ? 'updated' : 'skipped'}."}) if num_updated > 0
    end

    unless sourcedbs_added.empty?
      ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
      ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
      sourcedbs_added.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
    end

    File.unlink(filepath)
    FileUtils.rm_rf(dirpath) unless dirpath.nil?
    true
	end

end
