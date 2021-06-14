class AddSampleToAnnotator < ActiveRecord::Migration[4.2]
  def change
    add_column :annotators, :sample, :text
  end
end
