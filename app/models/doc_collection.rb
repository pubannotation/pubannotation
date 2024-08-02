class DocCollection
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
    request_count = 0

    if document_too_large?
      request_count = slice(@docs.first)
    else
      hdocs = docs.map{_1.hdoc}
      make_request(hdocs, @options)
      request_count = 1
    end

    request_count
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

    request_count
  end

  def make_request(hdocs, options)
    annotation_reception = AnnotationReception.create!(annotator_id: @annotator.id, project_id: @project.id, options:)
    method, url, params, payload = @annotator.prepare_request(hdocs)
    payload[:callback_url] = "#{Rails.application.config.host_url}/annotation_reception/#{annotation_reception.uuid}"

    @annotator.make_request(method, url, params, payload)
  end

  def document_too_large?
    @docs.length == 1 && @docs.first.body.length > @max_text_size
  end
end
