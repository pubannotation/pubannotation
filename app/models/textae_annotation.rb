class TextaeAnnotation < ApplicationRecord
  scope :older_than_one_day, -> { where("created_at < ?", 1.day.ago) }
end
