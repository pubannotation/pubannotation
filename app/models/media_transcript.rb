class MediaTranscript < ApplicationRecord
  belongs_to :doc

  delegate :medium, to: :doc, allow_nil: true

  validates :doc_id, uniqueness: true
  validate :doc_has_medium
  validate :medium_not_image

  private

  def doc_has_medium
    errors.add(:doc, 'must have an associated medium') if doc && medium.nil?
  end

  def medium_not_image
    errors.add(:medium, 'must not be an image') if medium&.image?
  end
end
