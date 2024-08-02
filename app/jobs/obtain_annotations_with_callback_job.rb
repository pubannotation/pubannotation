class ObtainAnnotationsWithCallbackJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :low_priority

  def perform(project, filepath, annotator, options)
    line_count = File.read(filepath).each_line.count

    prepare_progress_record(line_count)

    # for asynchronous protocol
    single_doc_processing_p = annotator.single_doc_processing?
    doc_collection = DocCollection.new(project, annotator, options, @job)

    File.foreach(filepath) do |line|
      docid = line.chomp.strip
      doc = Doc.find(docid)
      doc.set_ascii_body if options[:encoding] == 'ascii'

      if doc_collection.rest? && (single_doc_processing_p || (doc_collection.size + doc.body.length) > annotator.find_or_define_max_text_size)
        begin
          doc_collection.request_annotate
        rescue Exceptions::JobSuspendError
          raise
        rescue => e
          less_docs_message = 'Could not obtain annotations:'
          many_docs_message = 'Could not obtain annotations for'
          add_exception_message_to_job(doc_collection.docs, e, less_docs_message, many_docs_message)
        ensure
          doc_collection.clear
        end
      end

      doc_collection << doc

    rescue Exceptions::JobSuspendError
      raise
    rescue RuntimeError => e
      less_docs_message = 'Runtime error:'
      many_docs_message = 'Runtime error while processing'
      add_exception_message_to_job(doc_collection.docs, e, less_docs_message, many_docs_message)
    end

    if doc_collection.rest?
      doc_collection.request_annotate
    end

    File.unlink(filepath)
  end

  def job_name
    "Obtain annotations with callback: #{resource_name}"
  end

private

  def add_exception_message_to_job(docs, e, less_docs_message, many_docs_message)
    if docs.length < 10
      docs.each do |doc|
        @job.add_message sourcedb: doc.sourcedb,
                         sourceid: doc.sourceid,
                         body: "#{less_docs_message} #{exception_message(e)}"
      end
    else
      @job.add_message body: "#{many_docs_message} #{docs.length} docs: #{exception_message(e)}"
    end
  end

  def exception_message(exception)
    exception.message
  rescue => e
    "exception message inaccessible:\n#{exception}:\n#{exception.backtrace.join("\n")}"
  end

  def resource_name
    self.arguments[2].name
  end
end
