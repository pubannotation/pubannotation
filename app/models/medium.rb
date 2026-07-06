class Medium < ApplicationRecord
  has_one_attached :file

  belongs_to :user
  has_many :docs, dependent: :destroy

  enum :media_type, { image: 0, video: 1, audio: 2 }

  # Browsers only play these natively in an HTML5 <video>/<audio> tag;
  # e.g. video/quicktime (.mov) is rejected because Chrome/Firefox can't play it inline.
  ALLOWED_CONTENT_TYPES = %w[
    image/png image/jpeg image/gif image/webp
    video/mp4 video/webm
    audio/mpeg audio/wav audio/ogg
  ].freeze

  validates :sourcedb, presence: true
  validates :sourceid, presence: true, uniqueness: { scope: :sourcedb }
  validates :media_type, presence: true
  validates :content_type, presence: true, inclusion: { in: ALLOWED_CONTENT_TYPES }
end
