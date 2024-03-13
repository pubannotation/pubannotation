class SentenceDenotation < ApplicationRecord
  belongs_to :sentence, foreign_key: :block_id
  belongs_to :denotation
end
