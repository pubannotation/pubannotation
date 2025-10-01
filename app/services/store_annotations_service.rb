class StoreAnnotationsService
  DEFAULT_BATCH_SIZE = 100

  def initialize(project, annotations, options = {}, job: nil)
    @project = project
    @annotations = annotations
    @options     = options
    @job         = job
  end

  def call
    # Split annotations into batches
    @annotations.each_slice(DEFAULT_BATCH_SIZE) do |batch|
      process_batch(batch)
    end
  end

  private

  def process_batch(batch)
    # 1. Ensure documents are stored
    doc_ids = batch.flat_map(&:source_ids_list).uniq
    add_new_documents(doc_ids)

    # 2. Align text and apply annotations
    batch.each do |validated|
      apply_annotation(validated)
      @job&.increment!(:num_done) if @job
    end
  end

  def add_new_documents(doc_ids)
    # Bulk-add docs, capturing messages
    messages = @project.add_docs_in_bulk(doc_ids)
    messages.each { |m| @job&.add_message(format_message(m)) }
  end

  def apply_annotation(validated)
    # Perform alignment (originally in AlignTextInRactor)
    aligned_text = align_text(validated.text, validated.target)
    # Store the annotation into database
    @project.store_annotation(validated.doc_id, aligned_text, validated.metadata)
  end

  def align_text(source, target)
    # Simple alignment algorithm (e.g., two-pointer or dynamic programming)
    # Replace Ractor parallelism with direct DP
    TextAligner.align(source, target)
  end

  def format_message(msg)
    msg.is_a?(Hash) ? msg : { body: msg.to_s }
  end
end