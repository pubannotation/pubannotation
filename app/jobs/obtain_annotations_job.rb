class ObtainAnnotationsJob < Struct.new(:project, :docids, :annotator, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docids.length)
    @job.update_attribute(:num_dones, 0)

    docids.each_with_index do |docid, i|
      doc = Doc.find(docid)
      begin
        project.obtain_annotations(doc, annotator, options)
      rescue => e
				@job.messages << Message.create({item: "#{doc.sourcedb}:#{doc.sourceid}-#{doc.serial}", body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
