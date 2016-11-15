class DeleteAllDocsFromProjectJob < Struct.new(:project, :current_user)
	include StateManagement

	def perform
    docs = project.docs.dup
    sourcedbs = Set.new
		@job.update_attribute(:num_items, docs.length)
    @job.update_attribute(:num_dones, 0)
    docs.each_with_index do |doc, i|
      begin
        sourcedbs.add(doc.sourcedb)
        project.denotations.where(doc_id: doc.id).destroy_all
        project.docs.delete(doc)
        doc.destroy if doc.sourcedb.end_with?("#{Doc::UserSourcedbSeparator}#{current_user.username}") && doc.projects_num == 0
      rescue => e
        @job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, body: e.message})
      end
      @job.update_attribute(:num_dones, i + 1)
    end
    ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
    sourcedbs.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
    # project.update_attribute(:annotations_count, 0)
    # project.docs.clear
	end
end
