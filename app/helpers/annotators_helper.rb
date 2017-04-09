module AnnotatorsHelper

	def annotator_options
		Annotator.accessibles(current_user).order(:name).map{|a| [a[:name], a[:name]]}
	end

end
