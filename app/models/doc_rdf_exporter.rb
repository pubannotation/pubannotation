# frozen_string_literal: true

class DocRdfExporter
  def initialize(doc)
    @doc = doc
  end

  delegate :sourcedb, :sourceid, :body, :denotations, :blocks, to: :@doc

  def self.graph_uri
    "https://pubannotation.org/docs"
  end

  def graph_uri
    Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, only_path: false)
  end

  # the first argument, project_id, may be a single id or an array of ids
  def get_denotations_hash_all(project_id = nil)
    annotations = {}
    annotations[:denotations] = denotations.in_project(project_id).as_json + blocks.in_project(project_id).as_json
    annotations[:target] = Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(sourcedb, sourceid, :only_path => false)
    annotations[:sourcedb] = sourcedb
    annotations[:sourceid] = sourceid
    annotations[:text] = body
    annotations
  end

  def rdfizer_spans
    @rdfizer_spans ||= TAO::RDFizer.new(:spans)
  end

  # the first argument, project_id, may be a single id or an array of ids
  def get_spans_rdf(project_id, options = {})
    graph_uri_doc = self.graph_uri
    graph_uri_doc_spans = self.graph_uri + '/spans'

    doc_spans = self.get_denotations_hash_all(project_id)

    with_prefixes = options.has_key?(:with_prefixes) ? options[:with_prefixes] == true : false

    doc_spans_trig = ''

    if with_prefixes
      doc_spans_trig += rdfizer_spans.rdfize([doc_spans], {only_prefixes: true})
      doc_spans_trig += "@prefix oa: <http://www.w3.org/ns/oa#> .\n"
      doc_spans_trig += "@prefix prov: <http://www.w3.org/ns/prov#> .\n"
      doc_spans_trig += "\n"
    end

    if doc_spans && doc_spans[:denotations].present?
      doc_spans_ttl = rdfizer_spans.rdfize([doc_spans], {with_prefixes: false})
      doc_spans_trig += <<~HEREDOC
        <#{graph_uri_doc_spans}> rdf:type oa:Annotation ;
        \toa:has_body <#{graph_uri_doc_spans}> ;
        \toa:has_target <#{graph_uri_doc}> ;
        \tprov:generatedAtTime "#{DateTime.now.iso8601}"^^xsd:dateTime .

        GRAPH <#{graph_uri_doc_spans}>
        {
        \t#{doc_spans_ttl.gsub(/\n/, "\n\t")}
        }
      HEREDOC
    end

    doc_spans_trig
  end
end
