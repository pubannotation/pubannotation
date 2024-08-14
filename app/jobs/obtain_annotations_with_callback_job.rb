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

    doc_packer.each do |hdocs, doc|
      update_job_items(annotator, doc, hdocs.length)

      hdocs.each do |hdoc|
        begin
          make_request(annotator, project, [hdoc], options.merge(span: hdoc[:span]))
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
    annotation_reception = AnnotationReception.create!(annotator_id: annotator.id, project_id: project.id, job_id: @job.id, options:)
    method, url, params, payload = annotator.prepare_request(hdocs)
    payload[:callback_url] = "#{Rails.application.config.host_url}/annotation_reception/#{annotation_reception.uuid}"

    annotator.make_request(method, url, params, payload)
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

  def error_occured?(request_info)
    request_info.errors.reject(&:blank?).any?
  end

  def resource_name
    self.arguments[2].name
  end
end
