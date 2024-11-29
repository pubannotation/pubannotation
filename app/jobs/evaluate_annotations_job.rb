class EvaluateAnnotationsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(project, evaluation)
		reference_project = evaluation.reference_project

		soft_match_characters = evaluation.soft_match_characters || PubannotationEvaluator::SOFT_MATCH_CHARACTERS
		soft_match_words = evaluation.soft_match_words || PubannotationEvaluator::SOFT_MATCH_WORDS
		denotations_type_match = evaluation.denotations_type_match || PubannotationEvaluator::EXACT_TYPE_MATCH
		relations_type_match = evaluation.relations_type_match || PubannotationEvaluator::EXACT_TYPE_MATCH

		evaluator = PubannotationEvaluator.new(soft_match_characters, soft_match_words, denotations_type_match, relations_type_match)

		shared_doc_ids = project.get_shared_doc_ids(reference_project.id)
		prepare_progress_record(shared_doc_ids.length)

		comparison = []
		shared_doc_ids.each_with_index do |doc_id, i|
			doc = Doc.find(doc_id)
			annotations = doc.hannotations(project, nil, nil)
			reference_annotations = doc.hannotations(reference_project, nil, nil)
			comparison += evaluator.compare(annotations, reference_annotations)
			@job.update_attribute(:num_dones, i + 1)
		end

		result = evaluator.evaluate(comparison)

		unless reference_project.accessibility == 3
			false_positives = comparison.select{|m| m[:study] && m[:reference].nil?}
			result[:false_positives] = false_positives if false_positives.present?

			false_negatives = comparison.select{|m| m[:study].nil? && m[:reference]}
			result[:false_negatives] = false_negatives if false_negatives.present?

			true_positives = comparison.select{|m| m[:study] && m[:reference]}
			result[:true_positives] = true_positives unless true_positives.empty?
		end

		evaluation.update_attribute(:result, JSON.generate(result))
	end

	def job_name
		'Evaluate annotations'
	end
end
