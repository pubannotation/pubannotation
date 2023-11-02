# frozen_string_literal: true

# Data class representing the source of the document.
class DocumentSource
  attr_reader :db, :id

  def initialize(annotations)
    a = annotations.first

    @db = a[:sourcedb]
    @id = a[:sourceid]
  end
end
