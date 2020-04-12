require 'fileutils'
include AnnotationsHelper

class ImportAnnotationsJob < Struct.new(:source_project, :project)
	include StateManagement

	def perform
    docs = project.docs & source_project.docs

    @job.update_attribute(:num_items, docs.length)
    @job.update_attribute(:num_dones, 0)

    docs.each_with_index do |doc, i|
      begin
        annotations = doc.hannotations(source_project)
        messages = project.save_annotations!(annotations, doc)
        messages.each{|m| @job.messages << Message.create(m)}
      rescue => e
				@job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message})
      end
    	@job.update_attribute(:num_dones, i + 1)
    end
	end
end
