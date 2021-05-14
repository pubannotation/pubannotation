class AddSparqlEpToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :sparql_ep, :string
  end
end
