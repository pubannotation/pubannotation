class StoreAnnotationsCollectionZipJob < Struct.new(:filename, :project, :options)
	include StateManagement

	def perform
    files = Annotation.get_files_from_zip(filename)
    collection = Annotation.get_annotations_collection(files)

		@job.update_attribute(:num_items, collection.length)
    @job.update_attribute(:num_dones, 0)

    collection.each_with_index do |annotations, i|
      begin
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
				@job.messages << Message.create({item: "#{annotations[:sourcedb]}:#{annotations[:sourceid]}", body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
    File.unlink(filename)
	end
end
