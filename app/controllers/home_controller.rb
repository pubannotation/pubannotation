class HomeController < ApplicationController
	def index
		@sharedtasks_number = Collection.accessible(current_user).sharedtasks.length
		@sharedtasks_top_recent = Collection.accessible(current_user).sharedtasks.top_recent
		@collections_number = Collection.accessible(current_user).length
		@collections_top_recent = Collection.accessible(current_user).top_recent
		@projects_number = Project.accessible(current_user).length
		@projects_top_annotations_count = Project.accessible(current_user).for_home.top_annotations_count
		@projects_top_recent = Project.accessible(current_user).for_home.top_recent
		@news_notifications = NewsNotification.limit(5)
	end
end
