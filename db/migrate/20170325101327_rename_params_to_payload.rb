class RenameParamsToPayload < ActiveRecord::Migration
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
