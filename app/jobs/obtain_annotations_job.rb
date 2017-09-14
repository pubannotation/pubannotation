class ObtainAnnotationsJob < Struct.new(:project, :filepath, :annotator, :options)
	include StateManagement

	def perform
    count = %x{wc -l #{filepath}}.split.first.to_i

    @job.update_attribute(:num_items, count)
    @job.update_attribute(:num_dones, 0)

    # for asynchronous annotation
    retrieval_queue = []
    @skip_interval = nil

    batch_num = annotator[:batch_num]
    batch_num = 1 if batch_num.nil? || batch_num == 0

    File.foreach(filepath).each_slice(batch_num) do |docid_col|
      docid_col.each{|d| d.chomp!.strip!}
      begin
        r, messages = project.obtain_annotations(docid_col, annotator, options)
        messages.each{|m| @job.messages << (m.class == Hash ? Message.create(m) : Message.create({body: m}))}
        @job.update_attribute(:num_dones, @job.num_dones + docid_col.length)
      rescue RestClient::Exceptions::Timeout => e
        @job.messages << if batch_num == 1
          doc = Doc.find(docid_col.first)
          Message.create({sourcedb:doc.sourcedb, sourceid:doc.sourceid, body: "Could not obtain: #{e.message}"})
        else
          Message.create({body: "Could not obtain annotations for #{docid_col.length} docs: #{e.message}"})
        end
      rescue RestClient::ExceptionWithResponse => e
        if e.response.code == 303
          retry_after = e.response.headers[:retry_after].to_i
          if @skip_interval.nil?
            @skip_interval = retry_after / 10
            @skip_interval = 2 if @skip_interval < 2
            @skip_interval = 10 if @skip_interval > 10
          end
          retrieval_queue << {url:e.response.headers[:location], try_at: retry_after.seconds.from_now, retry_after: retry_after}
        elsif e.response.code == 503 # Service Unavailable
          if retrieval_queue.empty?
            @job.messages << Message.create({body: "Job execution stopped: service is unavailable when the queue is empty."})
            break
          end
          process_retrieval_queue(retrieval_queue)
          sleep(@skip_interval)
          retry
        elsif e.response.code == 404
          @job.messages << Message.create({body: "The annotator does not know the path."})
        else
          @job.messages << Message.create({body: "Message from the annotator: #{e.message}"})
        end
      rescue => e
        @job.messages += docid_col.map do |docid|
          doc = Doc.find(docid)
          Message.create({sourcedb:doc.sourcedb, sourceid:doc.sourceid, body: "Could not obtain: #{e.message}"})
        end
      end

      process_retrieval_queue(retrieval_queue) unless retrieval_queue.empty?
    end

    until retrieval_queue.empty?
      process_retrieval_queue(retrieval_queue)
      sleep(@skip_interval) unless retrieval_queue.empty?
    end

    File.unlink(filepath)
	end

  def process_retrieval_queue(queue)
    queue.each do |r|
      begin
        result = project.make_request(:get, r[:url])
        annotations_col = (result.class == Array) ? result : [result]

        annotations_col.each_with_index do |annotations, i|
          raise RuntimeError, "Invalid annotation JSON object." unless annotations.respond_to?(:has_key?)
          begin
            Annotation.normalize!(annotations, options[:prefix])
          rescue => e
            raise "Error during normalization #{e.message}"
          end
        end

        messages = project.store_annotations_collection(annotations_col, options)
        messages.each{|message| @job.messages << Message.create(message)}

        @job.update_attribute(:num_dones, @job.num_dones + annotations_col.length)
        r[:delme] = true
      rescue RestClient::ExceptionWithResponse => e
        if e.response.code == 404 # Not Found
          if r[:try_at] + ([r[:retry_after], @skip_interval].max * 9) < Time.now
            @job.messages << Message.create({body: "Retrieval of annotation failed after trials for 10 times longer than estimation."})
            r[:delme] = true
          end
        elsif e.response.code == 410 # Permanently removed
          @job.messages << Message.create({body: "Annotation result is removed from the server."})
          r[:delme] == true
        else
          @job.messages << Message.create({body: e.message})
        end
      rescue => e
        @job.messages << Message.create({body: "Error: #{e.message} : #{annotations_col}"})
      end
    end

    queue.delete_if{|r| r[:delme]}
  end
end
