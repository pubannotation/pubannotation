class Medium < ApplicationRecord
  has_one_attached :file

  belongs_to :user
  has_many :docs, dependent: :destroy

  enum :media_type, { image: 0, video: 1, audio: 2 }

  validates :sourcedb, presence: true
  validates :sourceid, presence: true, uniqueness: { scope: :sourcedb }
  validates :media_type, presence: true
  validates :content_type, presence: true
end
