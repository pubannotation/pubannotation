class RemoveUnnecessaryFieldsFromProjects < ActiveRecord::Migration
	def up
		change_table :projects do |t|
			t.rename :pmdocs_count, :docs_count
			t.remove :pmcdocs_count
			t.remove :pending_associate_projects_count
		end
	end

	def down
		change_table :projects do |t|
			t.rename :docs_count, :pmdocs_count
			t.integer :pmcdocs_count
			t.integer :pending_associate_projects_count
		end
	end
end
