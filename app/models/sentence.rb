# frozen_string_literal: true

class Sentence < ApplicationRecord
  self.table_name = 'blocks'
  default_scope { where obj: Pubann::Sentence::Obj }

  belongs_to :doc
  has_many :sentence_attrivutes, foreign_key: :block_id
  has_many :attrivutes, through: :sentence_attrivutes
  has_many :sentence_denotations, foreign_key: :block_id
  has_many :denotations, through: :sentence_denotations
end
