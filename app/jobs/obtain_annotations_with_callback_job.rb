class ObtainAnnotationsWithCallbackJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :low_priority

  def perform(project, filepath, annotator, options)
    count = %x{wc -l #{filepath}}.split.first.to_i

    if @job
      prepare_progress_record(count)
    end

    # for asynchronous protocol
    @max_text_size = annotator.max_text_size || (annotator.async_protocol ? Annotator::MaxTextAsync : Annotator::MaxTextSync)
    single_doc_processing_p = annotator.single_doc_processing?

    docs = []
    docs_size = 0
    File.foreach(filepath) do |line|
      docid = line.chomp.strip
      doc = Doc.find(docid)
      doc.set_ascii_body if options[:encoding] == 'ascii'
      doc_length = doc.body.length

      if docs.present? && (single_doc_processing_p || (docs_size + doc_length) > @max_text_size)
        begin
          if docs.length == 1 && docs.first.body.length > @max_text_size
            doc1 = docs.first
            slices = doc1.get_slices(@max_text_size)
            if @job
              count = @job.num_items + slices.length - 1
              @job.update_attribute(:num_items, count)
              if slices.length > 1
                @job.add_message sourcedb:doc1.sourcedb,
                                 sourceid:doc1.sourceid,
                                 body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."
              end
            end
            # delete all the annotations here for a better performance
            project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
            slices.each do |slice|
              begin
                make_request_batch(project, docs, annotator, options.merge(span:slice))
              rescue RuntimeError => e
                if e.class == Exceptions::JobSuspendError
                  raise e
                end
                if @job
                  @job.add_message sourcedb:doc1.sourcedb,
                                   sourceid:doc1.sourceid,
                                   body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
                end
              rescue => e
                if e.class == Exceptions::JobSuspendError
                  raise e
                end
                if @job
                  @job.add_message sourcedb:doc1.sourcedb,
                                   sourceid:doc1.sourceid,
                                   body: "Error while processing the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
                end
              end
            end
          else
            make_request_batch(project, docs, annotator, options)
          end
        rescue => e
          if e.class == Exceptions::JobSuspendError
            raise e
          elsif @job
            if docs.length < 10
              docs.each do |doc|
                @job.add_message sourcedb: doc.sourcedb,
                                 sourceid: doc.sourceid,
                                 body: "Could not obtain annotations: #{exception_message(e)}"
              end
            else
              @job.add_message body: "Could not obtain annotations for #{docs.length} docs: #{exception_message(e)}"
            end
          else
            raise e
          end
        ensure
          docs.clear
          docs_size = 0
        end
      end

      docs << doc
      docs_size += doc_length

    rescue RuntimeError => e
      if e.class == Exceptions::JobSuspendError
        raise e
      elsif @job
        if docs.length < 10
          docs.each do |doc|
            @job.add_message sourcedb: doc.sourcedb,
                             sourceid: doc.sourceid,
                             body: "Runtime error: #{exception_message(e)}"
          end
        else
          @job.add_message body: "Runtime error while processing #{docs.length} docs: #{exception_message(e)}"
        end
      else
        raise e
      end
    end

    if docs.present?
      begin
        if docs.length == 1 && docs.first.body.length > @max_text_size
          doc1 = docs.first
          slices = doc1.get_slices(@max_text_size)
          if @job
            count = @job.num_items + slices.length - 1
            @job.update_attribute(:num_items, count)
            if slices.length > 1
              @job.add_message sourcedb:doc1.sourcedb,
                               sourceid:doc1.sourceid,
                               body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."
            end
          end
          # delete all the annotations here for a better performance
          project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
          slices.each do |slice|
            make_request_batch(project, docs, annotator, options.merge(span:slice))
          rescue RuntimeError => e
            if e.class == Exceptions::JobSuspendError
              raise e
            elsif @job
              @job.add_message sourcedb:doc1.sourcedb,
                               sourceid:doc1.sourceid,
                               body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
            else
              raise e
            end
          end
        else
          make_request_batch(project, docs, annotator, options)
        end
      end
    end

    File.unlink(filepath)
  end

  def job_name
    "Obtain annotations: #{resource_name}"
  end

private

  def make_request_batch(project, docs, annotator, options)
    hdocs = if options[:span].present?
      doc = docs.first
      [{text:doc.get_text(options[:span]), sourcedb:doc.sourcedb, sourceid:doc.sourceid}]
    else
      docs.map{|d| d.hdoc}
    end

    uuid = SecureRandom.uuid
    AnnotationReception.create!(annotator_id: annotator.id, project_id: project.id, uuid:, options:)
    method, url, params, payload = annotator.prepare_request(hdocs, uuid)
    annotator.make_request(method, url, params, payload)
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
