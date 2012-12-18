class AddXmlwriterBionlpwriterToAnnset < ActiveRecord::Migration
  def change
    add_column :annsets, :xmlwriter, :string
    add_column :annsets, :bionlpwriter, :string
  end
end
