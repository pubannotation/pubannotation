class AddTypeToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :type, :string
  end
end
