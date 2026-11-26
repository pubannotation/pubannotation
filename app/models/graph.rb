class Graph
  def num_projects
  end

  def num_documents
  end

  def self.sparql_protocol_query_operation_get(ep_url, query, default_graph_uri = nil, named_graph_uri = nil, page = nil, page_size = nil)

    # to get the results of page_size + 1 items to know whether there is any more
    if page
      query = query + "\nLIMIT #{page_size + 1}\nOFFSET #{(page - 1) * page_size}"
    end

    params = {query: query}
    params[:default_graph_uri] = default_graph_uri if default_graph_uri
    params[:named_graph_uri] = named_graph_uri if named_graph_uri

    client = HTTPX.with(ssl: {verify_mode: OpenSSL::SSL::VERIFY_NONE})
    response = client.get(ep_url, params: params, headers: {'Accept' => 'application/sparql-results+json'})
    response.raise_for_status if response.is_a?(HTTPX::ErrorResponse)

    case response.status
    when 200
      JSON.parse(response.body.to_s, symbolize_names: true)
    when 400
      result = JSON.parse(response.body.to_s, symbolize_names: true)
      raise RuntimeError, result[:message]
    when 408, 504
      raise RuntimeError, "Request timeout: you are advised to re-try with a more specific query."
    when 502, 503
      raise RuntimeError, "SPARQL endpoint unavailable: please re-try after a few minutes, or contact the system administrator if the problem lasts long."
    else
      raise "HTTP #{response.status}"
    end
  rescue JSON::ParserError
    raise RuntimeError, "Received an invalid JSON object: [#{response.body}]"
  end

  QUERY_NUM_DOCUMENTS = <<~HEREDOC
		SELECT (COUNT(DISTINCT ?doc) AS ?count)
		WHERE {
			?span tao:belongs_to ?doc .
		}
	HEREDOC

  QUERY_PROJECTS = <<~HEREDOC
		SELECT ?project ?time
		WHERE {
			?project a pubann:Project .
			?project <http://www.w3.org/ns/prov#generatedAtTime> ?time
		}
	HEREDOC

end