class TermSearchController < ApplicationController
  include ArrayParameterConcern

  def index
    @query = params[:term_search_controller_query].present? ? Query.new(query_params) : Query.new
    return unless @query.valid?

    @query = Query.new query_params
    evidence_blocks = case @query.block_type
    in 'doc'
      Doc.search_by_term current_user,
                         @query.base_project,
                         to_array(@query.terms),
                         to_array(@query.predicates),
                         to_array(@query.projects),
                         @query.page,
                         @query.per
    in 'paragraph'
      Paragraph.search_by_term current_user,
                               @query.base_project,
                               to_array(@query.terms),
                               to_array(@query.predicates),
                               to_array(@query.projects),
                               @query.page,
                               @query.per
    in 'sentence'
      Sentence.search_by_term current_user,
                              @query.base_project,
                              to_array(@query.terms),
                              to_array(@query.predicates),
                              to_array(@query.projects),
                              @query.page,
                              @query.per
                      end

    @pub_annotation_url_list = evidence_blocks.map { convert_to_annotations_url_from _1, @query }
  end

  private

  def query_params
    params.require(:term_search_controller_query)
          .permit :block_type,
                  :base_project,
                  :terms, :predicates, :projects,
                  :page, :per
  end

  def convert_to_annotations_url_from(evidence_block, query)
    url = "#{evidence_block[:url]}/annotations.json"

    params2 = {
      'projects' => query.projects,
      'terms' => query.terms,
      'predicates' => query.predicates,
    }.select { |_, v| v.present? }

    unless query.block_type == 'doc'
      params2.merge!({
                       'begin' => evidence_block[:begin],
                       'end' => evidence_block[:end]
                     })
    end

    url << "?#{URI.encode_www_form(params2)}"
    url
  end

  class Query
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :block_type, :string
    attribute :base_project, :string
    attribute :terms, :string
    attribute :predicates, :string
    attribute :projects, :string
    attribute :page, :integer, default: 1
    attribute :per, :integer, default: 10

    def valid?(context = nil)
      terms.present? || predicates.present? || projects.present?
    end
  end
end
