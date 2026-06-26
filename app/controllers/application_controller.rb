# encoding: UTF-8

class ApplicationController < ActionController::Base
	protect_from_forgery

	def root_user?
		user_signed_in? && current_user.root?
	end

	def media_accessible?
		user_signed_in? && (current_user.root? || current_user.can_use_media?)
	end

	helper_method :root_user?
	helper_method :media_accessible?

	protected

	# Customize Devise rederct hooks
	# https://qiita.com/ryuuuuuuuuuu/items/b1ded4d17cce688b9732	
	def after_sign_in_path_for(resource)
		session[:after_sign_in_path] ||= root_path
	end

	def after_sign_out_path_for(resource_or_scope)
		request.referrer
	end

	def authenticate_root_user!
		unless root_user?
			render_status_error(:unauthorized)
		end
	end

	def render_status_error(status)
		# translation required for each httpstatus eg: errors.statuses.forbidden
		flash[:error] = t("errors.statuses.#{status}")
		render 'shared/status_error', :status => status
	end
end
