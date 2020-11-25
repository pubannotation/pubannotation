class NewsNotificationsController < ApplicationController
	before_filter :is_root_user?, except: [:index, :show, :category]

	def index
		@news_notifications = NewsNotification.limit(5) 
	end

	def category
		@news_notifications = NewsNotification.where('category = ?', params[:category]) 
		flash[:notice] = I18n.t('controllers.shared.not_exists', model: I18n.t('activerecord.models.news_notification')) if @news_notifications.blank?
	end

	def new
		@news_notification = NewsNotification.new() 
	end

	def create
		@news_notification = NewsNotification.new(params[:news_notification]) 
		if @news_notification.valid?
			@news_notification.save
			flash[:notice] = I18n.t('controllers.shared.successfully_created', model: I18n.t('activerecord.models.news_notification'))
			redirect_to @news_notification
		else
			render action: :new
		end
	end

	def show
		@news_notification = NewsNotification.find(params[:id])
	end

	def edit 
		@news_notification = NewsNotification.find(params[:id])
	end

	def update
		@news_notification = NewsNotification.find(params[:id])
		if @news_notification.update_attributes(params[:news_notification])
			flash[:notice] = I18n.t('controllers.shared.successfully_updated', model: I18n.t('activerecord.models.news_notification'))
			redirect_to @news_notification
		else
			render action: :edit
		end
	end

	def destroy
		@news_notification = NewsNotification.find(params[:id])
		@news_notification.destroy
		redirect_to news_notifications_path
	end
end
