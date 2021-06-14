class ChangeProjectReferenceToOrganizationReferenceQuery < ActiveRecord::Migration[4.2]
	def up
		change_table :queries do |t|
			t.rename :project_id, :organization_id
			t.string :organization_type, default: 'Project'
		end
	end

	def down
		change_table :queries do |t|
			t.rename :organization_id, :project_id
			t.remove :organization_type
		end
	end
end
