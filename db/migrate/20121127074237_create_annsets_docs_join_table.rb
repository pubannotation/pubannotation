class CreateAnnsetsDocsJoinTable < ActiveRecord::Migration
  def self.up
  	create_table :annsets_docs, :id => false do |t|
  		t.integer :annset_id, :doc_id
  	end
  	add_index :annsets_docs, [:annset_id, :doc_id], :unique => true
  end

  def self.down
  	drop_table :annsets_docs
  end
end
