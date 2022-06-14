# encoding: UTF-8
module ApplicationHelper

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

	def simple_paginate
		current_page = params[:page].nil? ? 1 : params[:page].to_i
		nav = ''
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-double-left", "aria-hidden" => "true"), params.permit(:controller, :action, :sort_key, :sort_direction).except(:page), title: "First", class: 'page') if current_page > 2
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-left", "aria-hidden" => "true"), params.permit(:controller, :action, :sort_key, :sort_direction).merge(page: current_page - 1), title: "Previous", class: 'page') if current_page > 1
		nav += content_tag(:span, "Page #{current_page}", class: 'page')
		nav += link_to(content_tag(:i, '', class: "fa fa-angle-right", "aria-hidden" => "true"), params.permit(:controller, :action, :sort_key, :sort_direction).merge(page: current_page + 1), title: "Next", class: 'page') unless params[:last_page]
		content_tag(:nav, nav.html_safe, class: 'pagination')
	end

	# render image tag and title attribute for hint
	def hint_helper(options = {})
		content_tag(:i, nil,
			class: "fa fa-question-circle", "aria-hidden" => "true",
			style: "color: green; font-size:1.2em",
			title: I18n.t("views.hints.#{options[:model]}.#{options[:column]}")
		)
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


	def get_ascii_text(text)
		rewritetext = Utfrewrite.utf8_to_ascii(text)
		#rewritetext = text

		# escape non-ascii characters
		coder = HTMLEntities.new
		asciitext = coder.encode(rewritetext, :named)
		# restore back
		# greek letters
		asciitext.gsub!(/&[Aa]lpha;/, "alpha")
		asciitext.gsub!(/&[Bb]eta;/, "beta")
		asciitext.gsub!(/&[Gg]amma;/, "gamma")
		asciitext.gsub!(/&[Dd]elta;/, "delta")
		asciitext.gsub!(/&[Ee]psilon;/, "epsilon")
		asciitext.gsub!(/&[Zz]eta;/, "zeta")
		asciitext.gsub!(/&[Ee]ta;/, "eta")
		asciitext.gsub!(/&[Tt]heta;/, "theta")
		asciitext.gsub!(/&[Ii]ota;/, "iota")
		asciitext.gsub!(/&[Kk]appa;/, "kappa")
		asciitext.gsub!(/&[Ll]ambda;/, "lambda")
		asciitext.gsub!(/&[Mm]u;/, "mu")
		asciitext.gsub!(/&[Nn]u;/, "nu")
		asciitext.gsub!(/&[Xx]i;/, "xi")
		asciitext.gsub!(/&[Oo]micron;/, "omicron")
		asciitext.gsub!(/&[Pp]i;/, "pi")
		asciitext.gsub!(/&[Rr]ho;/, "rho")
		asciitext.gsub!(/&[Ss]igma;/, "sigma")
		asciitext.gsub!(/&[Tt]au;/, "tau")
		asciitext.gsub!(/&[Uu]psilon;/, "upsilon")
		asciitext.gsub!(/&[Pp]hi;/, "phi")
		asciitext.gsub!(/&[Cc]hi;/, "chi")
		asciitext.gsub!(/&[Pp]si;/, "psi")
		asciitext.gsub!(/&[Oo]mega;/, "omega")

		# symbols
		asciitext.gsub!(/&apos;/, "'")
		asciitext.gsub!(/&lt;/, "<")
		asciitext.gsub!(/&gt;/, ">")
		asciitext.gsub!(/&quot;/, '"')
		asciitext.gsub!(/&trade;/, '(TM)')
		asciitext.gsub!(/&rarr;/, ' to ')
		asciitext.gsub!(/&hellip;/, '...')

		# change escape characters
		asciitext.gsub!(/&([a-zA-Z]{1,10});/, '==\1==')
		asciitext.gsub!('==amp==', '&')

		asciitext
	end
	
	def sanitize_sql(sql)
		# sanitized_sql = ActiveRecord::Base::sanitize(params[:sql])#.gsub('\'', '')
		sql.gsub("\"", '\'')
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

		link_to header, params.permit(:controller, :action).merge(sort_key: sort_key, sort_direction: next_sort_direction), {:class => "sortable-" + (current_sort_direction || 'none')}
	end

	def total_number(list, model = nil)
		if list.respond_to?(:total_entries)
			list.total_entries
		elsif list.respond_to?(:count)
			list.count
		else
			list.length if list.present?
		end
	end

	def gen_annotations (annotations, annserver, options = nil)
		response = if options && options[:method] == 'get'
			RestClient.get annserver, {:params => {:sourcedb => annotations[:sourcedb], :sourceid => annotations[:sourceid]}, :accept => :json}
		else
			# RestClient.post annserver, {:text => annotations[:text]}.to_json, :content_type => :json, :accept => :json
			RestClient.post annserver, :text => annotations[:text], :accept => :json
		end

		raise IOError, "Bad gateway" unless response.code == 200

		begin
			result = JSON.parse response, :symbolize_names => true
		rescue => e
			raise IOError, "Received a non-JSON object: [#{response}]"
		end

		ann = {}

		ann[:text] = if result.respond_to?(:has_key) && result.has_key?(:text)
			result[:text]
		else
			annotations[:text]
		end

		if result.respond_to?(:has_key?) && result.has_key?(:denotations)
			ann[:denotations] = result[:denotations]
			ann[:relations] = result[:relations] if defined? result[:relations]
			ann[:modifications] = result[:modifications] if defined? result[:modifications]
		elsif result.respond_to?(:first) && result.first.respond_to?(:has_key?) && result.first.has_key?(:obj)
			ann[:denotations] = result
		end

		ann
	end

	def root_user?
		user_signed_in? && current_user.root?
	end

	def manager?
		user_signed_in? && current_user.manager?
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
