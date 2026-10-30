# frozen_string_literal: true

module Doc::TextStructure
  extend ActiveSupport::Concern

  def store_divisions(items)
    Division.store_for(self, items)
  end

  def store_typesettings(items)
    Typesetting.store_for(self, items)
  end

  def update_all_references_in_paragraphs = paragraphs.each { _1.update_references denotations }

  def update_all_references_in_sentences = sentences.each { _1.update_references denotations }
end
