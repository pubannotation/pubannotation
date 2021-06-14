class ProjectsCountToNum < ActiveRecord::Migration[4.2]
  def up
  	change_table :docs do |t|
  		t.rename :projects_count, :projects_num
  	end
  end

  def down
  	change_table :docs do |t|
  		t.rename :projects_num, :projects_count
  	end
  end
end
