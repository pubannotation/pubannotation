# frozen_string_literal: true

class DocPresenter
  def initialize(doc)
    @doc = doc
  end

  delegate :body, :sourcedb, :sourceid, :source,
           :get_text, :get_divisions, :get_typesettings, to: :@doc

  def hdoc
    {
      text: body,
      sourcedb: sourcedb,
      sourceid: sourceid
    }
  end

  def to_hash(span = nil, context_size = nil)
    {
      target: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, only_path: false),
      sourcedb: sourcedb,
      sourceid: sourceid,
      source_url: source,
      text: get_text(span, context_size),
      divisions: get_divisions(span, context_size),
      typesettings: get_typesettings(span, context_size)
    }.reject{|k, v| k != :text && (v.nil? || v.empty?)}
  end

  def to_list_hash
    {
      sourcedb: sourcedb,
      sourceid: sourceid,
      url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(self.sourcedb, self.sourceid)
    }
  end

  def hannotations(projects, span, context_size,
                   terms: nil, predicates: nil,
                   is_sort: false, is_full: false, is_bag_denotations: false)
    annotations_hash = if projects.present?
                         AnnotationsHash.new @doc,
                           projects,
                           span,
                           context_size,
                           terms,
                           predicates,
                           is_sort,
                           is_full,
                           is_bag_denotations,
                           projects.respond_to?(:each) # When project is single, return annotations without track.
                       else
                         AnnotationsHash.new @doc,
                           nil,
                           span,
                           context_size,
                           terms,
                           predicates,
                           is_sort,
                           is_full,
                           is_bag_denotations,
                           true
                       end

    annotations_hash.to_hash
  end
end
