module AnnotatorsHelper

	def annotator_options
		Annotator.accessibles(current_user).order(:name).map{|a| [a[:name], a[:name]]}
	end

	def max_text_size(annotator)
		if annotator.max_text_size.present?
			number_with_delimiter(@annotator.max_text_size)
		elsif annotator.async_protocol
			number_with_delimiter(Annotator::MaxTextAsync) + ' (default)'
		else
			number_with_delimiter(Annotator::MaxTextSync) + ' (default)'
		end
	end


	def badge_is_public(annotator)
		badge, btitle = if annotator.is_public
		else
			['<i class="fa fa-ban" aria-hidden="true"></i>', 'Hidden']
		end

		badge.present? ? "<span class='badge' title='#{btitle}'>#{badge}</span>" : ""
	end
end
