class AddAnalysisToProject < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :analysis, :text
  end
end
