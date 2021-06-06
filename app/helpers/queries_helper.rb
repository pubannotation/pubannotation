module QueriesHelper

	def organization_path(organization)
		if organization.class == Project
			project_path(organization.name)
		else
			collection_path(organization.name)
		end
	end

	def organization_queries_path(organization)
		if organization
			if organization.class == Project
				project_queries_path(organization.name)
			else
				collection_queries_path(organization.name)
			end
		else
			queries_path
		end
	end

	def organization_query_path(query)
		organization = query.organization

		if organization
			if organization.class == Project
				project_query_path(organization.name, query)
			else
				collection_query_path(organization.name, query)
			end
		else
			query_path(query)
		end
	end

	def new_organization_query_path(organization)
		if organization
			if organization.class == Project
				new_project_query_path(organization.name)
			else
				new_collection_query_path(organization.name)
			end
		else
			new_query_path
		end
	end

	def edit_organization_query_path(query)
		organization = query.organization

		if organization
			if organization.class == Project
				edit_project_query_path(organization.name, query)
			else
				edit_collection_query_path(organization.name, query)
			end
		else
			edit_query_path(query)
		end
	end
end
