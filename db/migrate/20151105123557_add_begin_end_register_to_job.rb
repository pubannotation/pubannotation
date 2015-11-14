class AddBeginEndRegisterToJob < ActiveRecord::Migration
  def change
    add_column :jobs, :begun_at, :datetime
    add_column :jobs, :ended_at, :datetime
    add_column :jobs, :registered_at, :datetime
  end
end
