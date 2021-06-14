class AddSparqlEpToProjects < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :sparql_ep, :string
  end
end
