class AddDenotationsCountAndSubcatrelsCountToDocs < ActiveRecord::Migration
  def up
    add_column :docs, :denotations_count, :integer, :default => 0
    add_column :docs, :subcatrels_count, :integer, :default => 0

    Doc.reset_column_information
    Doc.all.each do |doc|
      Doc.update_counters doc.id, 
        :denotations_count => doc.denotations.length,
        :subcatrels_count => doc.subcatrels.length
    end    
  end

  def down
    remove_column :docs, :denotations_count
    remove_column :docs, :subcatrels_count
  end
end
