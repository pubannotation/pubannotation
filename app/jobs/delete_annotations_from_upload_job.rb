require 'fileutils'
include AnnotationsHelper

class DeleteAnnotationsFromUploadJob < Struct.new(:filepath, :project, :options)
	include StateManagement

	def perform
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

    docspecs = []
    jsonfiles.each_with_index do |jsonfile, i|
      json = File.read(jsonfile)
      begin
        o = JSON.parse(json, symbolize_names:true)
      rescue => e
        @job.messages << Message.create({body: "[#{File.basename(jsonfile)}] " + e.message})
        next
      end
      collection = o.is_a?(Array) ? o : [o]
      docspecs += collection.map{|o| {sourcedb:o[:sourcedb], sourceid:o[:sourceid], divid:o[:divid]}}
    end
    docspecs.uniq!

    # check annotation files
    @job.update_attribute(:num_items, docspecs.length)
    @job.update_attribute(:num_dones, 0)

    docspecs.each_with_index do |docspec, i|
      begin
        if docspec[:divid].present?
          doc = Doc.find_by_sourcedb_and_sourceid_and_serial(docspec[:sourcedb], docspec[:sourceid], docspec[:divid])
          project.delete_doc_annotations(doc) unless doc.nil?
        else
          divs = Doc.find_all_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
          divs.each{|div| project.delete_doc_annotations(div)} unless divs.nil?
        end
      rescue => e
        @job.messages << Message.create({sourcedb: docspec[:sourcedb], sourceid: docspec[:sourceid], divid: docspec[:divid], body: e.message})
      end
    	@job.update_attribute(:num_dones, i + 1)
    end

    File.unlink(filepath)
    FileUtils.rm_rf(dirpath) unless dirpath.nil?
	end
end
