# frozen_string_literal: true

class DocumentSourceIds
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

  def merge(index)
    raise unless @db == index.db

    @ids.merge index.ids
  end

  def ==(other)
    @db == other.db && self.ids == other.ids
  end
end
