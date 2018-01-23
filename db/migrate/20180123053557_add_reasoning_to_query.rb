class AddReasoningToQuery < ActiveRecord::Migration
  def change
    add_column :queries, :reasoning, :boolean, default: false
  end
end
