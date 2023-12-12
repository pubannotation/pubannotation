class TermSearchController < ApplicationController
  include ArrayParameterConcern

  def index
    @query = params[:term_search_controller_query].present? ? Query.new(query_params) : Query.new
    return unless @query.valid?

    @query = Query.new query_params
    doc_fields = Doc.search_by_term current_user,
                                    @query.base_project,
                                    to_array(@query.terms),
                                    to_array(@query.predicates),
                                    to_array(@query.projects),
                                    @query.page,
                                    @query.per

    @pub_annotation_url_list = doc_fields.map { |doc_field| convert_to_annotations_url_from doc_field }
  end

  private

  def query_params
    params.require(:term_search_controller_query)
          .permit :base_project,
                  :terms, :predicates, :projects,
                  :page, :per
  end

  def convert_to_annotations_url_from(doc_field)
    url = "#{doc_field[:url]}/annotations.json"

    params2 = {
      'projects' => params[:projects],
      'terms' => params[:terms],
      'predicates' => params[:predicates]
    }.compact

    url << "?#{URI.encode_www_form(params2)}" if params[:projects].present? || params[:terms].present? || params[:predicates].present?
    url
  end

  class Query
    include ActiveModel::Model
    include ActiveModel::Attributes

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
