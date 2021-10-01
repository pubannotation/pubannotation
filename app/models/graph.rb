class Graph
	def num_projects
	end

	def num_documents
	end

	def self.sparql_protocol_query_operation_get(ep_url, query, default_graph_uri = nil, named_graph_uri = nil)
		params = {query: query}
		params[:default_graph_uri] = default_graph_uri if default_graph_uri
		params[:named_graph_uri] = named_graph_uri if named_graph_uri

		response = RestClient::Request.execute(method: :get, url: ep_url, max_redirects: 0, headers:{params: params, accept: 'application/sparql-results+json'})

		raise "Unexpected response: #{response}" unless response.respond_to?(:code)

		case response.code
		when 200
			result = begin
				JSON.parse response, :symbolize_names => true
			rescue => e
				raise RuntimeError, "Received an invalid JSON object: [#{response}]"
			end
		when 400
			result = begin
				JSON.parse response, :symbolize_names => true
			rescue => e
				raise RuntimeError, "Received an invalid JSON object: [#{response}]"
			end
			raise RuntimeError, result[:message]
		when 408, 504
			raise RuntimeError, "Request timeout: you are advised to re-try with a more specific query."
		when 502, 503
			raise RuntimeError, "SPARQL endpoint unavailable: please re-try after a few minutes, or contact the system administrator if the problem lasts long."
		else
			raise RestClient::ExceptionWithResponse.new(response)
		end
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