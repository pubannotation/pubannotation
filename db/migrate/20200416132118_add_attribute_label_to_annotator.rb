class AddAttributeLabelToAnnotator < ActiveRecord::Migration
	def change
		add_column :annotators, :receiver_attribute, :string
		add_column :annotators, :new_label, :string
	end
end
