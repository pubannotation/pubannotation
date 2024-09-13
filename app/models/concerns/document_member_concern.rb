# frozen_string_literal: true

module DocMemberConcern
  extend ActiveSupport::Concern

  included do
    scope :in_doc, -> (doc_id) do
      where(doc_id: doc_id)
    end
  end
end
