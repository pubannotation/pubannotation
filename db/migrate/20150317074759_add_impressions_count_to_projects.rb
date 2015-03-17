class AddImpressionsCountToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :impressions_count, :integer, default: 0
  end
end
