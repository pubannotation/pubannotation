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

  def update_references(denotations)
    denotations.each do |denotation|
      if range.include?(denotation.range)
        paragraph_denotations.find_or_create_by denotation: denotation
        denotation.attrivutes.each do |attrivute|
          paragraph_attrivutes.find_or_create_by attrivute: attrivute
        end
      else
        paragraph_denotations.where(denotation: denotation).destroy_all
        denotation.attrivutes.each do |attrivute|
          paragraph_attrivutes.where(attrivute: attrivute).destroy_all
        end
      end
    end
  end

  private

  def range
    @range ||= (self.begin..self.end)
  end
end
