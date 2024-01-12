# frozen_string_literal: true

class Sentence < ApplicationRecord
  self.table_name = 'blocks'
  default_scope { where obj: Pubann::Sentence::Obj }

  belongs_to :doc
  has_many :sentence_attrivutes, foreign_key: :block_id
  has_many :attrivutes, through: :sentence_attrivutes
  has_many :sentence_denotations, foreign_key: :block_id
  has_many :denotations, through: :sentence_denotations

  # Sentences are a type of block, so they belong to the project.
  # However, the interpretation of sentences does not differ from project to project.
  # Sentences and denotations are considered related even if they belong to different projects.
  def update_references(denotations)
    denotations.each do |denotation|
      if range.include?(denotation.range)
        sentence_denotations.find_or_create_by denotation: denotation
        denotation.attrivutes.each do |attrivute|
          sentence_attrivutes.find_or_create_by attrivute: attrivute
        end
      else
        sentence_denotations.where(denotation: denotation).destroy_all
        denotation.attrivutes.each do |attrivute|
          sentence_attrivutes.where(attrivute: attrivute).destroy_all
        end
      end
    end
  end

  private

  def range
    @range ||= (self.begin..self.end)
  end
end
