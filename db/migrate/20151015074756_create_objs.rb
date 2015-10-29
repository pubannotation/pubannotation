class CreateObjs < ActiveRecord::Migration
  def change
    create_table :objs do |t|
      t.string :name
    end
  end
end
