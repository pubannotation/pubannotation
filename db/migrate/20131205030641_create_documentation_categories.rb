class CreateDocumentationCategories < ActiveRecord::Migration
  def change
    create_table :documentation_categories do |t|
      t.string :name, :null => false
    end
  end
end
