module AnnotatorsHelper
	def annotator_options
    Annotator.all.map{|a| [a[:abbrev], a[:abbrev]]}
	end
end
