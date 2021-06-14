class AddAnnotationsUpdatedAtToProjectDocs < ActiveRecord::Migration[4.2]
	def change
		add_column :project_docs, :annotations_updated_at, :datetime
	end
end
