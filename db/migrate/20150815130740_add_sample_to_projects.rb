class AddSampleToProjects < ActiveRecord::Migration
  def change
  	add_column :projects, :sample, :string
  end
end
