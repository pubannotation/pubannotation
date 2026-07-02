class Medium < ApplicationRecord
  has_one_attached :file

  belongs_to :user
  has_many :docs, dependent: :destroy

  enum :media_type, { image: 0, video: 1, audio: 2 }

  validates :sourcedb, presence: true
  validates :sourceid, presence: true, uniqueness: { scope: :sourcedb }
  validates :media_type, presence: true
  validates :content_type, presence: true

  def self.create_with_file(upload_entry, user:, io:)
    medium = new(upload_entry.medium_attributes(user:))
    medium.file.attach(io:, filename: upload_entry.filename, content_type: upload_entry.content_type)
    medium.save
    medium
  end
end
