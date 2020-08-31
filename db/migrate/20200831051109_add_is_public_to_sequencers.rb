class AddIsPublicToSequencers < ActiveRecord::Migration
  def change
    add_column :sequencers, :is_public, :boolean, default: false
  end
end
