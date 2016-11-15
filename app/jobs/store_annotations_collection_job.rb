class StoreAnnotationsCollectionJob < Struct.new(:collection, :project, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, collection.length)
    @job.update_attribute(:num_dones, 0)

    collection.each_with_index do |annotations, i|
      begin
       	project.add_doc(annotations[:sourcedb], annotations[:sourceid])

        if annotations[:divid].present?
          doc = Doc.find_by_sourcedb_and_sourceid_and_serial(annotations[:sourcedb], annotations[:sourceid], annotations[:divid])
        else
          doc = Doc.find_by_sourcedb_and_sourceid(annotations[:sourcedb], annotations[:sourceid])
          divs = doc.divs if doc
        end

        if doc.present? && divs.blank?
          project.save_annotations(annotations, doc, options)
        elsif divs.present?
          project.store_annotations(annotations, divs, options)
        else
          raise IOError, "document does not exist"
        end
      rescue => e
				@job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
