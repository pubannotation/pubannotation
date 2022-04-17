class AddBlocksNum < ActiveRecord::Migration[5.2]
	def change
		add_column :projects, :blocks_num, :integer, default: 0
		add_column :docs, :blocks_num, :integer, default: 0
		add_column :project_docs, :blocks_num, :integer, default: 0
	end
end
