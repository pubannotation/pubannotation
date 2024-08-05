class ObtainAnnotationsWithCallbackJob < ApplicationJob
  include UseJobRecordConcern
  include ActionView::Helpers::NumberHelper

  queue_as :low_priority

  def perform(project, filepath, annotator, options)
    doc_count = File.read(filepath).each_line.count

    prepare_progress_record(doc_count)

    # for asynchronous protocol
    doc_collection = DocCollection.new(project, annotator, options)

    File.foreach(filepath) do |line|
      docid = line.chomp.strip
      doc = Doc.find(docid)
      doc.set_ascii_body if options[:encoding] == 'ascii'

      if doc_collection.filled_with?(doc)
        begin
          request_info = doc_collection.request_annotate
          add_sliced_doc_exception_message_to_job(request_info, doc) if error_occured?(request_info)
          update_job_items(annotator, doc_collection.docs.first, request_info[:request_count])

        rescue Exceptions::JobSuspendError
          raise
        rescue StandardError, RestClient::RequestFailed => e
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
      begin
        request_info = doc_collection.request_annotate
        add_sliced_doc_exception_message_to_job(request_info, doc_collection.docs.first) if error_occured?(request_info)
        update_job_items(annotator, doc_collection.docs.first, request_info[:request_count])

      rescue StandardError, RestClient::RequestFailed => e
        less_docs_message = 'Could not obtain annotations:'
        many_docs_message = 'Could not obtain annotations for'
        add_exception_message_to_job(doc_collection.docs, e, less_docs_message, many_docs_message)
      end
    end

    File.unlink(filepath)
  end

  def job_name
    "Obtain annotations with callback: #{resource_name}"
  end

private

  def update_job_items(annotator, doc, request_count)
    count = @job.num_items + request_count - 1
    @job.update_attribute(:num_items, count)
    if request_count > 1
      @job.add_message sourcedb:doc.sourcedb,
                       sourceid:doc.sourceid,
                       body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(annotator.find_or_define_max_text_size)}). For proceding, it was divided into #{request_count} slices."
    end
  end

  def add_sliced_doc_exception_message_to_job(request_info, doc)
    slices = request_info[:slices]
    errors = request_info[:errors]

    slices.each_with_index do |slice, i|
      next if errors[i].blank?

      if errors[i].class == RuntimeError
        @job.add_message sourcedb:doc.sourcedb,
                          sourceid:doc.sourceid,
                          body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{errors[i].message}"
      else
        @job.add_message sourcedb:doc.sourcedb,
                        sourceid:doc.sourceid,
                        body: "Error while processing the slice (#{slice[:begin]}, #{slice[:end]}): #{errors[i].message}"
      end

    end
  end

  def add_exception_message_to_job(docs, e, less_docs_message, many_docs_message)
    if docs.length < 10
      docs.each do |doc|
        @job.add_message sourcedb: doc.sourcedb,
                         sourceid: doc.sourceid,
                         body: "#{less_docs_message} #{e.message}"
      end
    else
      @job.add_message body: "#{many_docs_message} #{docs.length} docs: #{e.message}"
    end
  end

  def error_occured?(request_info)
    request_info.key?(:errors) && request_info[:errors].reject(&:blank?).any?
  end

  def resource_name
    self.arguments[2].name
  end
end
