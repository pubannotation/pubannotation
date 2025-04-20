class AddDocsToProjectFromUploadJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(project, sourcedb, filepath)
    count = %x{wc -l #{filepath}}.split.first.to_i

    prepare_progress_record(count)

    @total_num_added = 0
    @total_num_sequenced = 0
    @total_num_existed = 0

    ids = []
    File.foreach(filepath).with_index do |line, i|
      line.chomp! && line.strip!
      line.sub!(/^PMC/, '')
      ids << line unless line.empty?

      if ids.length >= 1000
        add_docs(project, sourcedb, ids)
        ids.clear
      end

      @job&.update_attribute(:num_dones, i + 1)
      check_suspend_flag
    end

    add_docs(project, sourcedb, ids) unless ids.empty?

    # if @total_num_sequenced > 0
    #   Project.docs_stat_increment!(sourcedb, @total_num_sequenced)
    #   Project.docs_count_increment!(@total_num_sequenced)
    # end

    # if @total_num_added > 0
    #   project.docs_stat_increment!(sourcedb, @total_num_added)
    #   project.increment!(:docs_count, @total_num_added)
    # end

    File.unlink(filepath)
  ensure
    messages  = []
    messages << "#{@total_num_existed} doc(s) existed." if @total_num_existed > 0
    messages << "#{@total_num_added} doc(s) sequenced." if @total_num_sequenced > 0
    messages << "#{@total_num_added} doc(s) added."
    @job&.add_message body: messages.join(' ')
  end

  def job_name
    'Add docs to project from upload'
  end

  private

  def add_docs(project, sourcedb, ids)
    num_existed = project.docs.where(sourcedb: sourcedb, sourceid: ids).count
    num_added, num_sequenced, messages = begin
      project.add_docs(DocumentSourceIds.new(sourcedb, ids))
    rescue => e
      @job.add_message sourcedb: sourcedb,
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
  end
end
