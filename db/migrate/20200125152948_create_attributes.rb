class CreateAttributes < ActiveRecord::Migration[4.2]
	def change
		# 'attributes' is renamed to 'attrivute' to avoid conflict with the reserved word 'attributes'
		create_table :attrivutes do |t|
			t.string		:hid
			t.integer		:subj_id
			t.string		:subj_type
			t.string		:obj
			t.string		:pred
			t.integer		:project_id
			t.datetime	:created_at, null: false
			t.datetime	:updated_at, null: false
		end
		add_index :attrivutes, :project_id
		add_index :attrivutes, :subj_id
		add_index :attrivutes, :obj
	end
end
