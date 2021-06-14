class AddReasoningToQuery < ActiveRecord::Migration[4.2]
  def change
    add_column :queries, :reasoning, :boolean, default: false
  end
end
