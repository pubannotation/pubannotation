class AddAnnotatorRefToProject < ActiveRecord::Migration
	def up
		change_table :projects do |t|
			t.references :annotator, index: true
		end
	end
	def down
		change_table :projects do |t|
			t.remove :annotator_id
		end
	end
end
