class AddAnonymizeToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :anonymize, :boolean, :default => false, :null => false
  end
end
