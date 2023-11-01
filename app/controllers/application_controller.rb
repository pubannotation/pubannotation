# encoding: UTF-8

class ApplicationController < ActionController::Base
	protect_from_forgery

	def root_user?
		user_signed_in? && current_user.root?
	end

	helper_method :root_user?

	protected

	# Customize Devise rederct hooks
	# https://qiita.com/ryuuuuuuuuuu/items/b1ded4d17cce688b9732	
	def after_sign_in_path_for(resource)
		session[:after_sign_in_path] ||= root_path
	end

	def after_sign_out_path_for(resource_or_scope)
		request.referrer
	end

	def render_status_error(status)
		# translation required for each httpstatus eg: errors.statuses.forbidden
		flash[:error] = t("errors.statuses.#{status}")
		render 'shared/status_error', :status => status
	end
end
