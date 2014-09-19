class AddNamespacesToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :namespaces, :text
  end
end
