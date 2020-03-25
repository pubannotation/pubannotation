require 'fileutils'

class UploadDocsJob < Struct.new(:dirpath, :project, :options)
	include StateManagement

	def perform
    upfilepath = Dir.glob(File.join(dirpath, '**', '*')).first

    infiles = if upfilepath.end_with?('.json') || upfilepath.end_with?('.txt')
      [upfilepath]
    else
      unpackpath = File.join(dirpath, File.basename(upfilepath, ".*"))
      unpack_cmd = "mkdir #{unpackpath}; tar -xzf #{upfilepath} -C #{unpackpath}"
      unpack_success_p = system(unpack_cmd)
      raise IOError, "Could not unpack the archive file." unless unpack_success_p
      Dir.glob(File.join(unpackpath, '**', '*.json')) + Dir.glob(File.join(unpackpath, '**', '*.txt'))
    end.sort

    if @job
      @job.update_attribute(:num_items, infiles.length)
      @job.update_attribute(:num_dones, 0)
    end

    username = project.user
    mode = options[:mode]
    num_updated = 0
    sourcedbs_added = Set[]
    infiles.each_with_index do |fpath, i|
      begin
        ext = File.extname(fpath)
        fname = File.basename(fpath, ext)

        doc_hash = case ext
        when '.json'
          json = File.read(fpath)
          doc_hash = JSON.parse(json, symbolize_names:true)
        when '.txt'
          fparts = fname.split('-')
          raise "The filename is expected to be in the form 'sourcedb-sourceid.txt'." unless fparts.length == 2

          text = File.read(fpath)

          {
            text: text,
            sourcedb: fparts[0],
            sourceid: fparts[1]
          }
        end

        doc_hash = Doc.prepare_creation(doc_hash, username, options[:root] == true)

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
        message = "[#{fpath}] #{e.message}"
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
      ActionController::Base.new.expire_fragment("sourcedb_counts")
      ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
      ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
      sourcedbs_added.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
    end

    FileUtils.rm_rf(dirpath) unless dirpath.nil?
    true
	end

end
