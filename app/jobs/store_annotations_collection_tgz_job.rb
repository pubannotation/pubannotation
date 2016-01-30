require 'fileutils'
include AnnotationsHelper

class StoreAnnotationsCollectionTgzJob < Struct.new(:filepath, :project, :options)
	include StateManagement

	def perform
    dirpath = File.join('tmp', File.basename(filepath, ".*"))
    unpack_cmd = "mkdir #{dirpath}; tar -xzf #{filepath} -C #{dirpath}"
    unpack_success_p = system(unpack_cmd)
    raise IOError, "Could not unpack the archive file." unless unpack_success_p
    jsonfiles = Dir.glob(File.join(dirpath, '**', '*.json'))

    # check annotation files
    @job.update_attribute(:num_items, jsonfiles.length)
    @job.update_attribute(:num_dones, 0)

    jsonfiles.each_with_index do |jsonfile, i|
      json = File.read(jsonfile)
      begin
        o = JSON.parse(json, symbolize_names:true)
      rescue => e
        @job.messages << Message.create({item: "#{File.basename(jsonfile)}", body: e.message})
        next
      end
      annotation_collection = o.is_a?(Array) ? o : [o]

      annotation_collection.each do |annotations|
        begin
          raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotations[:sourcedb].present? && annotations[:sourceid].present?
          normalize_annotations!(annotations)
         	project.add_doc(annotations[:sourcedb], annotations[:sourceid])

          if annotations[:divid].present?
            doc = Doc.find_by_sourcedb_and_sourceid_and_serial(annotations[:sourcedb], annotations[:sourceid], annotations[:divid])
          else
            divs = Doc.find_all_by_sourcedb_and_sourceid(annotations[:sourcedb], annotations[:sourceid])
            doc = divs[0] if divs.length == 1
          end

          if doc.present?
            project.save_annotations(annotations, doc, options)
          elsif divs.present?
            project.store_annotations(annotations, divs, options)
          else
            raise IOError, "document does not exist"
          end
        rescue => e
          annotations[:sourcedb] = '-' unless annotations[:sourcedb].present?
          annotations[:sourceid] = '-' unless annotations[:sourceid].present?
  				@job.messages << Message.create({item: "#{annotations[:sourcedb]}:#{annotations[:sourceid]}", body: e.message})
        end
      end
    	@job.update_attribute(:num_dones, i + 1)
    end
    Doc.index_diff if Doc.diff_flag
    File.unlink(filepath)
    FileUtils.rm_rf(dirpath)
	end
end
