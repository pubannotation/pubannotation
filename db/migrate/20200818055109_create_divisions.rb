class CreateDivisions < ActiveRecord::Migration[4.2]
	def change
		create_table :divisions do |t|
			t.belongs_to :doc
			t.string :label
			t.integer :begin
			t.integer :end

			t.timestamps
		end
	end
end
