class ObtainAnnotationsWithCallbackJob < ApplicationJob
  include UseJobRecordConcern
  include ActionView::Helpers::NumberHelper

  queue_as :low_priority

  def perform(project, filepath, annotator, options)
    doc_count = File.read(filepath).each_line.count
    prepare_progress_record(doc_count)

    doc_packer = DocPacker.new(annotator, encoding: options[:encoding])

    File.foreach(filepath) do |line|
      doc_packer << line.chomp.strip
    end

    doc_packer.each do |hdocs, doc, error|
      if error
        add_exception_message_to_job(doc, error)
        next
      end

      update_job_items(annotator, doc, hdocs) if hdocs.any? { _1.key?(:span) }

      hdocs_to_request = annotator.single_doc_processing? ? hdocs.map { [_1] } : [hdocs]
      hdocs_to_request.each do |hdoc|
        begin
          make_request(annotator, project, hdoc, options)
        rescue StandardError, RestClient::RequestFailed => e
          add_exception_message_to_job(hdoc, e)
          break if e.class == RestClient::InternalServerError
        end
      end
    end

    File.unlink(filepath)
  end

  def job_name
    "Obtain annotations with callback: #{resource_name}"
  end

private

  def make_request(annotator, project, hdocs, options)
    hdoc_metadata = hdocs.map do |hdoc|
      {
        docid: hdoc[:docid],
        span: hdoc[:span]
      }
    end
    annotation_reception = AnnotationReception.create!(annotator_id: annotator.id, project_id: project.id, job_id: @job.id, options:, hdoc_metadata:)
    method, url, params, payload = annotator.prepare_request(hdocs)

    payload, payload_type =
      if payload.class == String
        [payload, 'text/plain; charset=utf8']
      else
        [payload.to_json, 'application/json; charset=utf8']
      end

    callback_url = "#{Rails.application.config.host_url}/annotation_reception/#{annotation_reception.uuid}"
    RestClient::Request.execute(method:, url:, payload:, max_redirects: 0, headers:{content_type: payload_type, accept: :json, callback_url:}, verify_ssl: false)
  end

  def update_job_items(annotator, doc, request_count)
    count = @job.num_items + request_count - 1
    @job.update_attribute(:num_items, count)
    if request_count > 1
      @job.add_message sourcedb:doc.sourcedb,
                       sourceid:doc.sourceid,
                       body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(annotator.find_or_define_max_text_size)}). For proceding, it was divided into #{request_count} slices."
    end
  end

  def add_exception_message_to_job(hdoc, e)
    e_explanation =
      if hdoc[:span].present?
        if e.class == RuntimeError
          "Could not obtain for the slice (#{hdoc[:span][:begin]}, #{hdoc[:span][:end]}):"
        else
          "Error while processing the slice (#{hdoc[:span][:begin]}, #{hdoc[:span][:end]}):"
        end
      else
        "Could not obtain annotations:"
      end

    @job.add_message sourcedb: hdoc[:sourcedb],
                     sourceid: hdoc[:sourceid],
                     body: "#{e_explanation} #{e.message}"
  end

  def resource_name
    self.arguments[2].name
  end
end
