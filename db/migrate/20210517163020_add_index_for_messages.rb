class AddIndexForMessages < ActiveRecord::Migration
	def change
		add_index :messages, [:job_id, :created_at]
	end
end
