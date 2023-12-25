# frozen_string_literal: true

class Paragraph < ApplicationRecord
  self.table_name = 'divisions'
  default_scope { where label: 'p' }

  has_many :paragraph_attrivutes, foreign_key: :division_id
  has_many :attrivutes, through: :paragraph_attrivutes
  has_many :paragraph_denotations, foreign_key: :division_id
  has_many :denotations, through: :paragraph_denotations

  scope :with_term, lambda { |term|
    joins(:attrivutes)
      .where(attrivutes: { obj: term })

  }
end
