class AddIndexForMessages < ActiveRecord::Migration[4.2]
	def change
		add_index :messages, [:job_id, :created_at]
	end
end
