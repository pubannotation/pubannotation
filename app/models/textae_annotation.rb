class TextaeAnnotation < ApplicationRecord
  before_create :clean_old_annotations

  scope :old, -> { where("created_at < ?", 1.day.ago) }

  private

  def clean_old_annotations
    TextaeAnnotation.old.destroy_all
  end
end
