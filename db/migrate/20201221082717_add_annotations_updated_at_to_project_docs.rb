class AddAnnotationsUpdatedAtToProjectDocs < ActiveRecord::Migration
	def change
		add_column :project_docs, :annotations_updated_at, :datetime
	end
end
