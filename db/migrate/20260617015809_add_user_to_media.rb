class AddUserToMedia < ActiveRecord::Migration[8.1]
  def change
    add_reference :media, :user, null: false, foreign_key: true
  end
end
