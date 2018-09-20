class AddUnconfirmedEmailUser < ActiveRecord::Migration
  def up
    add_column :users, :unconfirmed_email, :string
  end

  def down
  end
end
