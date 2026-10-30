# frozen_string_literal: true

class RdfIndexStatus
  def self.last_indexed_at(graph_uri, endpoint = nil)
    if endpoint.nil?
      endpoint = stardog(Rails.application.config.ep_url, user: Rails.application.config.ep_user, password: Rails.application.config.ep_password)
    end
    db = Rails.application.config.ep_database
    result = endpoint.query(db, "select ?o where {<#{graph_uri}> <http://www.w3.org/ns/prov#generatedAtTime> ?o}")
    begin
      DateTime.parse(result.body["results"]["bindings"].first["o"]["value"])
    rescue
      nil
    end
  end
end
