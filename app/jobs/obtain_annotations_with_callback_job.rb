class ObtainAnnotationsWithCallbackJob < ApplicationJob
  include UseJobRecordConcern
  include ActionView::Helpers::NumberHelper

  queue_as :low_priority

  def perform(project, filepath, annotator, options)
    doc_packer = DocPacker.new(annotator, encoding: options[:encoding])

    File.foreach(filepath) do |line|
      doc_packer << line.chomp.strip
    end

    prepare_progress_record(doc_packer.request_count)

    doc_packer.each do |hdocs, doc, error, slice_count|
      # Handle document slice error
      if error
        add_exception_message_to_job(hdocs, error)
        next
      end

      add_slice_message_to_job(annotator, doc, slice_count) if slice_count.present?

      begin
        make_request(annotator, project, hdocs, options)
      rescue StandardError, RestClient::RequestFailed => e
        add_exception_message_to_job(hdocs, e)
        break if e.class == RestClient::InternalServerError
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

    RestClient::Request.execute(
      method:,
      url:,
      payload:,
      max_redirects: 0,
      headers: {
        content_type: payload_type,
        accept: :json,
        'Annotation-Reception-Callback-URL' => "#{Rails.application.config.host_url}/annotation_reception/#{annotation_reception.uuid}"
      },
      verify_ssl: false
    )
  end

  def add_slice_message_to_job(annotator, doc, slice_count)
    @job.add_message sourcedb:doc.sourcedb,
                     sourceid:doc.sourceid,
                     body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(annotator.find_or_define_max_text_size)}). For proceding, it was divided into #{slice_count} slices."
  end

  def add_exception_message_to_job(hdocs, e)
    e_explanation =
      if hdocs.length == 1 && hdocs.first[:span].present?
        if e.class == RuntimeError
          "Could not obtain for the slice (#{hdocs.first[:span][:begin]}, #{hdocs.first[:span][:end]}):"
        else
          "Error while processing the slice (#{hdocs.first[:span][:begin]}, #{hdocs.first[:span][:end]}):"
        end
      else
        "Could not obtain annotations:"
      end

    @job.add_message sourcedb: hdocs.map { _1[:sourcedb] }.uniq.join(', '),
                     sourceid: hdocs.map { _1[:sourceid] }.uniq.join(', '),
                     body: "#{e_explanation} #{e.message}"
  end

  def resource_name
    self.arguments[2].name
  end
end
