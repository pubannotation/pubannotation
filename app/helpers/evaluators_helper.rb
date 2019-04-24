module EvaluatorsHelper
	def access_type_helper(evaluator)
		case evaluator.access_type
		when 1
			'gem'
		when 2
			'web'
		else
			'unknown'
		end
	end

	def evaluator_options_helper
		Evaluator.accessibles(current_user).order(:name).map{|a| [a[:name], a[:name]]}
	end
end
