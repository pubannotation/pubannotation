class UpdateAnnotationNumbersJob < Struct.new(:dummy)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, Doc.count)
    @job.update_attribute(:num_dones, 0)

    Doc.all.each_with_index do |doc, i|
      begin
        doc.update_numbers
      rescue => e
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
