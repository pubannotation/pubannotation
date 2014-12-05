class AddProcessToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :process, :integer
  end
end
