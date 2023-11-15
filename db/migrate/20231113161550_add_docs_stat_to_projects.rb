class AddDocsStatToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :docs_stat, :json, default: {}
  end
end
