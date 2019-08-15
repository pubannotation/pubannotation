class AddSampleToAnnotator < ActiveRecord::Migration
  def change
    add_column :annotators, :sample, :text
  end
end
