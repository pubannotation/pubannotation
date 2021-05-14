class AddSparqlEpToCollections < ActiveRecord::Migration
  def change
    add_column :collections, :sparql_ep, :string
  end
end
