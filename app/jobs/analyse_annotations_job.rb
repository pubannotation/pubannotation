class AnalyseAnnotationsJob < ApplicationJob
	queue_as :low_priority

	def perform(project, options)
		docs = project.docs

		if @job
			prepare_progress_record(docs.count)
		end

		analysis = {
			embeddings:[],
			bcrossings:[],
			duplabels:[]
		}

		docs.each_with_index do |doc, i|
			begin
				annotations = doc.hannotations(project)
				a = Annotation.analyse(annotations)

				analysis[:embeddings] += a[:embeddings]
				analysis[:bcrossings] += a[:bcrossings]
				analysis[:duplabels] += a[:duplabels]
			rescue => e
				if @job
					@job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], body: e.message})
				else
					raise e
				end
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end

		project.update_attribute(:analysis, JSON.generate(analysis))
	end

	def job_name
		'Analyse project annotations'
	end
end
