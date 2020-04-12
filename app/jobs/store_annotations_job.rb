class StoreAnnotationsJob < Struct.new(:annotations, :project, :divs, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1)
		@job.update_attribute(:num_dones, 0)
		messages = project.save_annotations_divs(annotations, divs, options)
		messages.each{|m| @job.messages << Message.create(m)}
		@job.update_attribute(:num_dones, 1)
	end
end
