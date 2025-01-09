class CreateTextaeAnnotations < ActiveRecord::Migration[8.0]
  def change
    create_table :textae_annotations do |t|
      t.string :uuid, default: -> { "gen_random_uuid()" }, null: false
      t.text :annotation

      t.timestamps
    end
  end
end
