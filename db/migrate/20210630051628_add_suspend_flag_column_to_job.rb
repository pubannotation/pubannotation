class AddSuspendFlagColumnToJob < ActiveRecord::Migration[5.2]
  def change
    add_column :jobs, :suspend_flag, :boolean, default: false
  end
end
