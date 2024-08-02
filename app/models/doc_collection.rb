class DocCollection
  include ActionView::Helpers::NumberHelper

  attr_accessor :docs
  attr_reader :size

  def initialize(project, annotator, options, job)
    @project = project
    @annotator = annotator
    @max_text_size = annotator.find_or_define_max_text_size
    @options = options
    @job = job
    @docs = []
    @size = 0
  end

  def request_annotate
    if @docs.length == 1 && @docs.first.body.length > @max_text_size
      slice_large_document(@docs.first)
    else
      hdocs = docs.map{|d| d.hdoc}
      make_request(hdocs, @options)
    end
  end

  def filled_for?(doc)
    single_doc_processing_p = @annotator.single_doc_processing?
    rest? && (single_doc_processing_p || (@size + doc.body.length) > @max_text_size)
  end

  def <<(doc)
    @docs << doc
    @size += doc.body.length
  end

  def rest?
    @docs.any?
  end

  def clear
    @docs.clear
    @size = 0
  end

  private

  def slice_large_document(doc)
    slices = doc.get_slices(@max_text_size)
    count = @job.num_items + slices.length - 1
    @job.update_attribute(:num_items, count)
    if slices.length > 1
      @job.add_message sourcedb:doc.sourcedb,
                       sourceid:doc.sourceid,
                       body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."
    end

    # delete all the annotations here for a better performance
    @project.delete_doc_annotations(doc) if @options[:mode] == 'replace'
    slices.each do |slice|
      hdoc = [{text:doc.get_text(@options[:span]), sourcedb:doc.sourcedb, sourceid:doc.sourceid}]
      make_request(hdoc, @options.merge(span:slice))
    rescue Exceptions::JobSuspendError
      raise
    rescue RuntimeError => e
      @job.add_message sourcedb:doc.sourcedb,
                       sourceid:doc.sourceid,
                       body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
    rescue => e
      @job.add_message sourcedb:doc.sourcedb,
                       sourceid:doc.sourceid,
                       body: "Error while processing the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
    end
  end

  def make_request(hdocs, options)
    uuid = SecureRandom.uuid
    AnnotationReception.create!(annotator_id: @annotator.id, project_id: @project.id, uuid:, options:)
    method, url, params, payload = @annotator.prepare_request(hdocs)
    payload[:callback_url] = "#{Rails.application.config.host_url}/annotation_reception/#{uuid}"

    @annotator.make_request(method, url, params, payload)
  end
end
