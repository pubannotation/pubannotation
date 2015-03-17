class AddImpressionsCountToDocs < ActiveRecord::Migration
  def change
    add_column :docs, :impressions_count, :integer, default: 0
  end
end
