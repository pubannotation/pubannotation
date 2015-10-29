class CreatePreds < ActiveRecord::Migration
  def change
    create_table :preds do |t|
      t.string :name
    end
  end
end
