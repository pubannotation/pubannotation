module RelationsHelper
	def relations_num_helper(project, options = {})
		if params[:action] == 'spans'
			relations = @doc.hrelations(project, {:begin => params[:begin], :end => params[:end]})
			relations.present? ? relations.size : 0
		else 
			if project.present?
				if options[:doc].present?
					options[:doc].project_relations_num(project.id)
				else 
					project.relations_num
				end
			else
				options[:doc].relations_num
			end
		end
	end
end
