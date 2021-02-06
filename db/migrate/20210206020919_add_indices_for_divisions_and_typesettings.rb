class AddIndicesForDivisionsAndTypesettings < ActiveRecord::Migration
	def change
		add_index :divisions, :doc_id
		add_index :typesettings, :doc_id
	end
end
