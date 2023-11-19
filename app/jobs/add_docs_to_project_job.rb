class AddDocsToProjectJob < ApplicationJob
  queue_as :general

  def perform(project, docspecs)
    prepare_progress_record(docspecs.length)

    @total_num_added = 0
    @total_num_sequenced = 0
    @total_num_existed = 0

    docspecs_group_by_sourcedb = docspecs.group_by { |docspec| docspec[:sourcedb] }
    i = 0
    docspecs_group_by_sourcedb.each do |sourcedb, docspecs|
      ids = docspecs.map { |docspec| docspec[:sourceid] }
      num_existed = project.docs.where(sourcedb: sourcedb).count
      num_added, num_sequenced, messages = begin
                                              project.add_docs(DocumentSourceIds.new(sourcedb, ids))
                                            rescue => e
                                                @job&.add_message sourcedb: sourcedb,
                                                                 sourceid: "#{ids.first} - #{ids.last}",
                                                                 body: e.message
                                                [0, 0, 0, []]
                                            end

      @total_num_added += num_added
      @total_num_sequenced += num_sequenced
      @total_num_existed += num_existed

      messages.each do |message|
        @job&.add_message(message.class == Hash ? message : { body: message })
      end

      i += docspecs.length
      @job&.update_attribute(:num_dones, i)
      check_suspend_flag
    end

    if @total_num_sequenced > 0
      Project.docs_stat_increment!(sourcedb, @total_num_sequenced)
      Project.docs_count_increment!(@total_num_sequenced)
    end

    sourcedbs = docspecs_group_by_sourcedb.keys
    unless sourcedbs.empty?
      project.increment!(:docs_count, @total_num_added)
      sourcedbs.uniq.each {|sourcedb| project.docs_stat_increment!(sourcedb, @total_num_added)}
    end

  ensure
    if @total_num_existed > 0
      @job&.add_message body: "#{@total_num_existed} doc(s) existed. #{@total_num_added} doc(s) added."
    end
  end

  def job_name
    'Add docs to project'
  end
end
