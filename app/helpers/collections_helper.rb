module CollectionsHelper
	def badge_sharedtask(collection)
		collection.is_sharedtask ? "<span class='badge' title='shared task'><i class='fa fa-bullseye' aria-hidden='true'></i></span>" : ""
	end

	def badge_open(collection)
		if collection.is_open
			content_tag(:i, '', class: "fa fa-sign-in", "aria-hidden" => "true", title: "This is an open collection, to which anyone can add his/her own projects.")
		else
			''
		end
	end

	def collection_home_button
		link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), @collection.reference, :class => 'home_button' if @collection.reference.present?
	end

	def icon_job(collection)
		if collection.has_running_jobs?
			content_tag(:i, '', class: "fa fa-cog fa-spin fa-lg", "aria-hidden" => "true", title: "jobs")
		elsif collection.has_waiting_jobs?
			content_tag(:i, '', class: "fa fa-cog fa-pulse fa-lg", "aria-hidden" => "true", title: "jobs")
		else
			content_tag(:i, '', class: "fa fa-cog fa-lg", "aria-hidden" => "true", title: "jobs")
		end
	end

end
