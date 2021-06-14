class RenameParamsToPayload < ActiveRecord::Migration[4.2]
  def up
   	change_table :annotators do |t|
  		t.rename :params, :payload
  	end
  end

  def down
   	change_table :annotators do |t|
  		t.rename :payload, :params
  	end
  end
end
