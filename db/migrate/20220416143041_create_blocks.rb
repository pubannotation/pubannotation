class CreateBlocks < ActiveRecord::Migration[5.2]
	def change
		create_table :blocks do |t|
			t.string   :hid
			t.integer  :doc_id
			t.integer  :begin
			t.integer  :end
			t.string   :obj
			t.integer  :project_id

			t.timestamps
		end
	end
end
