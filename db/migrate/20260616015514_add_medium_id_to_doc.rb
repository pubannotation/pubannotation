class AddMediumIdToDoc < ActiveRecord::Migration[8.1]
  def change
    add_reference :docs, :medium, foreign_key: true, index: true
  end
end
