class ParagraphDenotation < ApplicationRecord
  belongs_to :paragraph, foreign_key: :division_id
  belongs_to :denotation
end
