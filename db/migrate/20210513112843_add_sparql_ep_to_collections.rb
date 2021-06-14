class AddSparqlEpToCollections < ActiveRecord::Migration[4.2]
  def change
    add_column :collections, :sparql_ep, :string
  end
end
