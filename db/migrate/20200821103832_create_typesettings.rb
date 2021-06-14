class CreateTypesettings < ActiveRecord::Migration[4.2]
	def change
		create_table :typesettings do |t|
			t.belongs_to :doc
			t.string :style
			t.integer :begin
			t.integer :end

			t.timestamps
		end
	end
end
