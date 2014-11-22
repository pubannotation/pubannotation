class AddSuccessfulAndUriAndMethodToNotices < ActiveRecord::Migration
  def change
    add_column :notices, :successful, :boolean
    add_column :notices, :uri, :text
    add_column :notices, :method, :string
  end
end
