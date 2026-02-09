class AddDocsToProjectJob < ApplicationJob
  include UseJobRecordConcern

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
                                                                 sourceid: ids,
                                                                 body: e.message
                                                [0, 0, []]
                                            end

      @total_num_added += num_added
      @total_num_sequenced += num_sequenced
      @total_num_existed += num_existed

      if num_sequenced > 0
        Project.docs_stat_increment!(sourcedb, num_sequenced)
        Project.docs_count_increment!(num_sequenced)
      end

      messages.each do |message|
        @job&.add_message(message)
      end

      i += docspecs.length
      @job&.update_attribute(:num_dones, i)
      check_suspend_flag
    end

  ensure
    Elasticsearch::IndexQueue.schedule_processing if @total_num_added.to_i > 0
    if @total_num_existed.to_i > 0
      @job&.add_message body: "#{@total_num_existed} doc(s) existed. #{@total_num_added} doc(s) added."
    end
  end

  def job_name
    'Add docs to project'
  end
end
