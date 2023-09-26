# frozen_string_literal: true

# Data class representing annotations as a hash
class AnnotationsHash
  def initialize(doc, span, context_size, is_sort, is_full, options, project_doc_list, has_track)
    @doc = doc
    @span = span
    @context_size = context_size
    @is_sort = is_sort
    @is_full = is_full
    @options = options
    @has_track = has_track
    @project_doc_list = project_doc_list
  end

  def to_hash
    hash = @doc.to_hash(@span, @context_size)

    if has_track?
      hash[:tracks] = @project_doc_list.inject([]) do |tracks, project_doc |
        track = annotations_in project_doc
        if full? || track[:denotations].present?
          tracks << track
        else
          tracks
        end
      end
    else
      project_doc = @project_doc_list.first
      hash.merge!(annotations_in project_doc)
    end

    hash
  end

  private

  def annotations_in(project_doc)
    project_doc.get_annotations(@span, @context_size, sort?, @options)
  end

  def sort? = @is_sort

  def full? = @is_full

  def has_track? = @has_track
end
