class ObtainAnnotationsJob < Struct.new(:project, :docs, :annotator, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docs.length)
    @job.update_attribute(:num_dones, 0)

    docs.each_with_index do |doc, i|
      begin
        doc.set_ascii_body if options[:encoding] == 'ascii'
        project.obtain_annotations(doc, annotator, options)
      rescue => e
				@job.messages << Message.create({item: "#{doc.sourcedb}:#{doc.sourceid}-#{doc.serial}", body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
