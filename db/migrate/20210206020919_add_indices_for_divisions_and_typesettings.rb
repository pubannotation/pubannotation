class AddIndicesForDivisionsAndTypesettings < ActiveRecord::Migration[4.2]
	def change
		add_index :divisions, :doc_id
		add_index :typesettings, :doc_id
	end
end
