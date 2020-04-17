
class ObtainAnnotationsJob < Struct.new(:project, :filepath, :annotator, :options)
  include StateManagement
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper

  def perform
    count = %x{wc -l #{filepath}}.split.first.to_i

    if @job
      @job.update_attribute(:num_items, count)
      @job.update_attribute(:num_dones, 0)
    end

    # for asynchronous protocol
    @annotation_tasks_queue = []
    @max_text_size = annotator.max_text_size || (annotator.async_protocol ? Annotator::MaxTextAsync : Annotator::MaxTextSync)
    single_doc_processing_p = annotator.single_doc_processing?
    skip_interval = Annotator::SkipInterval

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
              @job.messages << Message.create({sourcedb:doc1.sourcedb, sourceid:doc1.sourceid, body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."}) if slices.length > 1
            end
            # delete all the annotations here for a better performance
            project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
            slices.each do |slice|
              make_request_batch(docs, annotator, options.merge(span:slice))
            rescue RuntimeError => e
              @job.messages << Message.create({sourcedb:doc1.sourcedb, sourceid:doc1.sourceid, body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{e.message}"}) if @job
            end
          else
            make_request_batch(docs, annotator, options)
          end
        ensure
          docs.clear
          docs_size = 0
        end
      end

      docs << doc
      docs_size += doc_length

      process_tasks_queue unless @annotation_tasks_queue.empty?
    rescue RestClient::ServiceUnavailable => e
      if @job
        @job.messages << Message.create({body: message})
        exit
      else
        raise RuntimeError, message
      end
    rescue RuntimeError => e
      if docs.length == 1
        doc = docs.first
        if @job
          @job.messages << Message.create({sourcedb:doc.sourcedb, sourceid:doc.sourceid, body: "Could not obtain: #{e.message}"})
        else
          raise e
        end
      else
        if @job
          @job.messages << Message.create({body: "Could not obtain annotations for #{docs.length} docs: #{e.message}"})
        else
          raise e
        end
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
            @job.messages << Message.create({sourcedb:doc1.sourcedb, sourceid:doc1.sourceid, body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."}) if slices.length > 1
          end
          # delete all the annotations here for a better performance
          project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
          slices.each do |slice|
            make_request_batch(docs, annotator, options.merge(span:slice))
          rescue RuntimeError => e
            @job.messages << Message.create({sourcedb:doc1.sourcedb, sourceid:doc1.sourceid, body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{e.message}"}) if @job
          end
        else
          make_request_batch(docs, annotator, options)
        end
      end
    end

    until @annotation_tasks_queue.empty?
      process_tasks_queue
      sleep(skip_interval) unless @annotation_tasks_queue.empty?
    end

    File.unlink(filepath)
	end

private

  def make_request_batch(docs, annotator, options)
    hdocs = if options[:span].present?
      doc = docs.first
      [{text:doc.get_text(options[:span]), sourcedb:doc.sourcedb, sourceid:doc.sourceid}]
    else
      docs.map{|d| d.hdoc}
    end
    timer_start = Time.now
    annotations_col = annotator.obtain_annotations(hdocs)
    ttime = Time.now - timer_start

    ## In case of synchronous protocol
    timer_start = Time.now
    text_length = annotations_col.reduce(0){|sum, annotations| sum += annotations[:text].length}
    timer_start = Time.now
    messages = if options[:span].present?
      project.save_annotations!(annotations_col.first, docs.first, options)
    else
      project.store_annotations_collection(annotations_col, options)
    end
    messages.each{|m| @job.messages << Message.create(m)}
    stime = Time.now - timer_start

    if @job
      num = annotations_col.reduce(0){|sum, annotations| sum += annotations[:denotations].length}
      @job.messages << Message.create({body: "Annotation obtained, sync (ttime:#{ttime}, stime:#{stime}, length:#{text_length}, num:#{num})"}) if options[:debug]
      @job.update_attribute(:num_dones, @job.num_dones + docs.length)
    end
  rescue RestClient::ServiceUnavailable => e
    if @service_unavailable_begins_at.present?
      raise e if (Time.now - @service_unavailable_begins_at) > 3600
    else
      @service_unavailable_begins_at = Time.now
    end
    retry_after = e.response.headers[:retry_after].to_i if e.response.headers[:retry_after].present?
    if @annotation_tasks_queue.empty?
      sleep(retry_after || 5)
    else
      process_tasks_queue
    end
    retry
  rescue RestClient::ExceptionWithResponse => e
    if e.response.present?
      case e.response.code
      when 201
        ## In case of asynchronous protocol
        task = {url: e.response.headers[:location]}
        task.merge!(span:options[:span], docid:docs.first.id) if options[:span].present?
        @annotation_tasks_queue << task
        @service_unavailable_begins_at = nil
      else
        raise e
      end
    else
      raise e
    end
  end

  def process_tasks_queue
    @annotation_tasks_queue.each do |task|
      status = annotator.make_request(:get, task[:url])
      case status[:status]
      when 'DONE'
        task[:delme] = true
        result = annotator.make_request(:get, status[:result_location])
        annotations_col = (result.class == Array) ? result : [result]
        annotations_col.each_with_index do |annotations, i|
          raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
          Annotation.normalize!(annotations)
          annotator.annotations_transform!(annotations)
        end

        timer_start = Time.now
        messages = if task[:span].present?
          project.save_annotations!(annotations_col.first, Doc.find(task[:docid]), options.merge(span:task[:span]))
        else
          project.store_annotations_collection(annotations_col, options)
        end
        messages.each{|m| @job.messages << Message.create(m)}

        stime = Time.now - timer_start

        if @job
          ptime = status[:finished_at].to_time - status[:started_at].to_time
          qtime = status[:started_at].to_time - status[:submitted_at].to_time
          length = annotations_col.reduce(0){|sum, annotations| sum += annotations[:text].length}
          num = annotations_col.reduce(0){|sum, annotations| sum += annotations[:denotations].length}
          @job.messages << Message.create({body: "Annotation obtained, async (qtime:#{qtime}, ptime:#{ptime}, stime:#{stime}, length:#{length}, num:#{num})"}) if options[:debug]
          @job.update_attribute(:num_dones, @job.num_dones + annotations_col.length)
        end
      when 'ERROR'
        task[:delme] = true
        raise RuntimeError, "The annotation server issued an error message: #{status[:error_message]}."
      when 'IN_QUEUE'
        if Time.now - status[:submitted_at].to_time > Annotator::MaxWaitInQueueBatch
          raise RestClient::ServiceUnavailable, "The task is terminated because a task has been waiting for more than #{Annotator::MaxWaitInQueue} in the queue."
        end
      when 'IN_PROGRESS'
        if Time.now - status[:started_at].to_time > Annotator::MaxWaitInProcessingBatch
          raise RestClient::ServiceUnavailable, "The task is terminated because a task has been in processing for more than #{Annotator::MaxWaitInProcessing}."
        end
      else
        task[:delme] = true
        raise RuntimeError, "The annotation server reported an unknown status of the annotation task: #{status[:status]}."
      end
    end

  ensure
    @annotation_tasks_queue.delete_if{|task| task[:delme]}
  end

end
