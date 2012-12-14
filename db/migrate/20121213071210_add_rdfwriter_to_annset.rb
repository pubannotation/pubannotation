class AddRdfwriterToAnnset < ActiveRecord::Migration
  def change
    add_column :annsets, :rdfwriter, :string
  end
end
