class MediaTranscript < ApplicationRecord
  belongs_to :medium
  belongs_to :doc

  validates :doc_id, uniqueness: true
  validate :medium_not_image

  private

  def medium_not_image
    errors.add(:medium, 'must not be an image') if medium&.image?
  end
end
