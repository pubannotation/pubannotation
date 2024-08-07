class DocCollection
  attr_accessor :docs
  attr_reader :size

  def initialize(project, annotator, job_id, options)
    @project = project
    @annotator = annotator
    @max_text_size = annotator.find_or_define_max_text_size
    @job_id = job_id
    @options = options
    @docs = []
    @size = 0
  end

  def request_annotate
    request_info = {}

    if document_too_large?
      request_info = slice(@docs.first)
    else
      hdocs = docs.map{_1.hdoc}
      make_request(hdocs, @options)
      request_info[:request_count] = 1
    end

    request_info
  end

  def filled_with?(doc)
    rest? && (@annotator.single_doc_processing? || (@size + doc.body.length) > @max_text_size)
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

  def slice(doc)
    slices = doc.get_slices(@max_text_size)
    request_count = slices.length

    # delete all the annotations here for a better performance
    @project.delete_doc_annotations(doc) if @options[:mode] == 'replace'
    errors = []

    slices.each do |slice|
      begin
        hdoc = [{text:doc.get_text(slice), sourcedb:doc.sourcedb, sourceid:doc.sourceid}]
        make_request(hdoc, @options.merge(span:slice))
        errors << ""
      rescue RestClient::InternalServerError => e
        errors << e
        break
      rescue => e
        errors << e
      end
    end

    {request_count:, slices:, errors:}
  end

  def make_request(hdocs, options)
    annotation_reception = AnnotationReception.create!(annotator_id: @annotator.id, project_id: @project.id, job_id: @job_id, options:)
    method, url, params, payload = @annotator.prepare_request(hdocs)
    payload[:callback_url] = "#{Rails.application.config.host_url}/annotation_reception/#{annotation_reception.uuid}"

    @annotator.make_request(method, url, params, payload)
  end

  def document_too_large?
    @docs.length == 1 && @docs.first.body.length > @max_text_size
  end
end
