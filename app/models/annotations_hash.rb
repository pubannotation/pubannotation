# frozen_string_literal: true

# A class that collects annotations for a document.
class AnnotationsHash
  # Annotations may belong to multiple projects.
  # When putting annotations from multiple projects into the hash, the has_track option should be enabled.
  # Otherwise, only the annotation of the first project will be put into the hash.
  def initialize(doc, span, context_size, is_sort, is_full, is_bag_denotations, project_doc_list, has_track)
    @doc = doc
    @span = span
    @context_size = context_size
    @is_sort = is_sort
    @is_full = is_full
    @is_bag_denotations = is_bag_denotations
    @has_track = has_track
    @project_doc_list = project_doc_list
  end

  def to_hash
    hash = @doc.to_hash(@span, @context_size)

    if has_track?
      hash[:tracks] = annotations_tracks
    else
      project_doc = @project_doc_list.first
      hash.merge!(annotations_in project_doc)
    end

    hash
  end

  private

  def annotations_tracks
    @annotations_tracks ||= @project_doc_list.inject([]) do |tracks, project_doc |
      track = annotations_in project_doc
      if full? || track[:denotations].present?
        tracks << track
      else
        tracks
      end
    end
  end

  def annotations_in(project_doc)
    project_doc.get_annotations(@span, @context_size, sort?, bag_denotations?)
  end

  # If true, multiple project annotations are set to the track property.
  def has_track? = @has_track

  # When true, annotations with a Denotation of 0 are also set to the track property.
  def full? = @is_full

  # If true, Denotation, Block, and Relation are reordered.
  def sort? = @is_sort

  def bag_denotations? = @is_bag_denotations
end
