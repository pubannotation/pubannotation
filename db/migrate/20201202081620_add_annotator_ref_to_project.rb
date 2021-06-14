class AddAnnotatorRefToProject < ActiveRecord::Migration[4.2]
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
