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
        project.save_annotations(annotations, doc)
      rescue => e
        docspec = "#{annotations[:sourcedb]}:#{annotations[:sourceid]}"
        docspec += "-#{annotations[:divid]}" unless annotations[:divid].nil?
				@job.messages << Message.create({item: docspec, body: e.message})
      end
    	@job.update_attribute(:num_dones, i + 1)
    end
	end
end
