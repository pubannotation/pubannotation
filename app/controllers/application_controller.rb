# encoding: UTF-8
require 'pmcdoc'
require 'utfrewrite'
require 'text_alignment'

class ApplicationController < ActionController::Base
	protect_from_forgery
	before_action :cors_set_access_control_headers
	before_action :set_locale
	after_action :store_location

	protected

	# Customize Devise rederct hooks
	# https://qiita.com/ryuuuuuuuuuu/items/b1ded4d17cce688b9732	
	def after_sign_in_path_for(resource)
		session[:after_sign_in_path] ||= root_path
	end

	def after_sign_out_path_for(resource_or_scope)
		request.referrer
	end
	
	def cors_set_access_control_headers
		if request.referer.present?
			uri = URI.parse(request.referer)
			referer_uri = "#{uri.scheme}://#{uri.host}"
			referer_uri += ":#{uri.port}" unless uri.port == 80 || uri.port == 443

			response.headers['Access-Control-Allow-Origin'] = referer_uri
			response.headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, PATCH, DELETE, OPTIONS'
			response.headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, Token, ' \
				'Auth-Token, Email, X-User-Token, X-User-Email, x-xsrf-token'
			response.headers['Access-Control-Max-Age'] = '86400'
			response.headers['Access-Control-Allow-Credentials'] = 'true'
		end
	end

	def set_locale
		accept_locale = ['en', 'ja']
		if params[:locale].present? && accept_locale.include?(params[:locale])
			session[:locale] = params[:locale]
		end
		
		if session[:locale].blank?
			accept_language = request.env['HTTP_ACCEPT_LANGUAGE'] ||= 'en'
			locale_string = accept_language.scan(/^[a-z]{2}/).first
			if accept_locale.include?(locale_string.to_s)
				locale = locale_string
			else
				locale = :en
			end
			I18n.locale =  locale
		else
			I18n.locale = session[:locale]
		end
	end

	def store_location
		requested_path = url_for(:only_path => true)
		if requested_path != new_user_session_path && requested_path != new_user_registration_path && (requested_path =~ /password/).blank?  && request.method == 'GET'
			session[:after_sign_in_path] = request.fullpath
		end
	end

	def render_status_error(status)
		# translation required for each httpstatus eg: errors.statuses.forbidden
		flash[:error] = t("errors.statuses.#{status}")
		render 'shared/status_error', :status => status
	end
end
