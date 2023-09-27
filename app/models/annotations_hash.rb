# frozen_string_literal: true

# A class that collects annotations for a document.
class AnnotationsHash
  # Annotations may belong to multiple projects.
  # When putting annotations from multiple projects into the hash, the has_track option should be enabled.
  # Otherwise, only the annotation of the first project will be put into the hash.
  def initialize(doc, projects, span, context_size, is_sort, is_full, is_bag_denotations, has_track)
    @doc = doc
    @span = span
    @context_size = context_size
    @is_sort = is_sort
    @is_full = is_full
    @is_bag_denotations = is_bag_denotations
    @has_track = has_track
    @project_doc_list = if projects.present?
                          doc.project_docs.where(project: projects)
                        else
                          doc.project_docs
                        end
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
    @annotations_tracks ||= @project_doc_list.inject([]) do |tracks, project_doc|
      track = annotations_in project_doc
      if full? || track[:denotations].present?
        tracks << track
      else
        tracks
      end
    end
  end

  def annotations_in(project_doc)
    _annotations = project_doc.annotation_in @span
    _annotations.as_json(is_sort: @is_sort,
                         is_bag_denotations: @is_bag_denotations,
                         span: @span,
                         context_size: @context_size)
  end

  # If true, multiple project annotations are set to the track property.
  def has_track? = @has_track

  # When true, annotations with a Denotation of 0 are also set to the track property.
  def full? = @is_full
end
