# frozen_string_literal: true

class DocumentSourceIndex
  attr_reader :db

  def initialize(db, ids)
    @db = db
    @ids = Set.new(ids)
  end

  def ids
    @ids.to_a
  end

  def <<(id)
    @ids << id
  end
end
