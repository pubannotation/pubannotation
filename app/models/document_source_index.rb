# frozen_string_literal: true

class DocumentSourceIndex
  attr_reader :index

  def initialize(annotations = [])
    @index = Hash.new

    build_index annotations
  end

  def merge(other)
    other.index.each do |sourcedb, sourceids|
      if @index[sourcedb]
        @index[sourcedb].merge sourceids
      else
        @index[sourcedb] = sourceids
      end
    end
  end

  def values
    @index.values
  end

  private

  def build_index(annotation)
    annotation.each do |annotation|
      ids = DocumentSourceIds.new(annotation[:sourcedb], [annotation[:sourceid]])

      if @index[annotation[:sourcedb]]
        @index[annotation[:sourcedb]].merge ids
      else
        @index[annotation[:sourcedb]] = ids
      end
    end
  end
end
