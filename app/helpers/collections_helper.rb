module CollectionsHelper
	def badge_sharedtask(collection)
		collection.is_sharedtask ? "<span class='badge' title='shared task'><i class='fa fa-bullseye' aria-hidden='true'></i></span>" : ""
	end

	def collection_maintainer_link(collection)
		link_to collection.user.username, show_user_path(collection.user.username)
	end

	def collection_home_button
		link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), @collection.reference, :class => 'home_button' if @collection.reference.present?
	end
end
