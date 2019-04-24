class EvaluateAnnotationsJob < Struct.new(:evaluation)
	include StateManagement

	def perform
    project = evaluation.study_project
    reference_project = evaluation.reference_project

    docs = project.docs & reference_project.docs

		@job.update_attribute(:num_items, docs.count)
		@job.update_attribute(:num_dones, 0)

		evaluator = PubannotationEvaluator.new
		comparison = []
		docs.each_with_index do |doc, i|
			annotations = doc.hannotations(project)
			reference_annotations = doc.hannotations(reference_project)
			comparison += evaluator.compare(annotations, reference_annotations)
			@job.update_attribute(:num_dones, i + 1)
		end

		result = evaluator.evaluate(comparison)

		if reference_project.accessibility == 1
			false_positives = comparison.select{|m| m[:study] && m[:reference].nil?}
			result[:false_positives] = false_positives if false_positives.present?

			false_negatives = comparison.select{|m| m[:study].nil? && m[:reference]}
			result[:false_negatives] = false_negatives if false_negatives.present?
		end

		evaluation.update_attribute(:result, JSON.generate(result))
	end
end
