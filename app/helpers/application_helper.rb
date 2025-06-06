# encoding: UTF-8
module ApplicationHelper

	def button(type, path, title)
		icon = case type
		when :edit
			'edit'
		when :create
			'plus-square'
		when :delete
			'minus-square'
		when :destroy
			'bomb'
		else
			raise 'Button of unknown type'
		end

		link_to fa_icon(icon), path, title: title
	end

	def button_destroy(path, title)
		link_to fa_icon('trash'), path, method: :delete, title: title, data: { confirm: t('views.confirm_dangerous_process') }
	end

	def button_home(url)
		# link_to t('activerecord.attributes.project.reference'), @project.reference, :class => 'home_button' if @project.reference.present?
		link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), url, :class => 'home_button' if url.present?
	end

	def badge_public(is_public)
		is_public ?
			"<span class='badge' title='Public'><i class='fa fa-eye' aria-hidden='true'></i></span>" :
			""
	end

	def badge_private(is_public)
		if is_public
			""
		else
			content_tag(:i, '', class: "fa fa-eye-slash", "aria-hidden" => "true", title: "private")
		end
	end

	def errors_helper(model)
		if model.errors.count > 0
			model_name = t("activerecord.models.#{model.class.to_s.downcase}")
			if model.errors.count == 1
				errors_header = t('errors.template.header.one', :model => model_name)
			else
				errors_header = t('errors.template.header.other', :model => model_name, :count => model.errors.count)
			end
			render :partial => 'shared/errors', :locals => {:model => model, :errors_header => errors_header }
		end
	end
	
	def language_switch_helper
		requested_path = url_for(:only_path => false, :overwrite_params => nil)
		en_text = 'English'
		if I18n.locale != :en
			en_text = link_to en_text, requested_path + '?locale=en'
		end
		ja_text = '日本語'
		if I18n.locale != :ja
			ja_text = link_to ja_text, requested_path + '?locale=ja'
		end
		"<ul><li>#{en_text}</li><li>#{ja_text}</li></ul>"
	end

	def sortable(model, header, sort_key, initial_sort_direction = 'DESC')
		current_sort_direction = if params[:sort_key].present? && params[:sort_key] == sort_key && params[:sort_direction].present?
			params[:sort_direction]
		elsif (defined? model::DefaultSort) && (sort_match = model::DefaultSort.assoc sort_key)
			sort_match[1]
		else
			nil
		end

		next_sort_direction = if current_sort_direction.nil?
			initial_sort_direction
		else
			current_sort_direction == 'ASC' ? 'DESC' : 'ASC'
		end

		link_to header, params.permit(:controller, :action, :project_id, :sourcedb).merge(sort_key: sort_key, sort_direction: next_sort_direction), {:class => "sortable-" + (current_sort_direction || 'none')}
	end

	def name_with_private_indicator(object)
		str  = object.name
		str += ' '
		if (object.respond_to?(:is_public) && !object.is_public) || (object.respond_to?(:accessibility) && object.accessibility == 2)
			str += content_tag(:i, '', class: "fa fa-eye-slash", "aria-hidden" => "true", title: "private")
		elsif object.respond_to?(:accessibility) && object.accessibility == 3
			str += content_tag(:i, '', class: "fa fa-bars", "aria-hidden" => "true", title: "private")
		end
		str
	end
end
