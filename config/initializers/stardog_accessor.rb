require 'stardog'

# stardog-rb calls File.exists?, which was removed in Ruby 3.2.
module StardogFileCompatibility
  def update_in_transaction(database, transaction_id, update, graph_uri = nil)
    params = {"graph-uri" => graph_uri} if graph_uri
    update = File.read(update) if File.exist?(update)

    http_request("POST", "#{database}/#{transaction_id}/update", "*/*", params, update, false, "application/sparql-update", nil)
  end

  def add_in_transaction(database, transaction_id, body, graph_uri = nil, content_type = "text/plain")
    params = {"graph-uri" => graph_uri} if graph_uri
    if File.exist?(body)
      body = File.read(body)
    elsif body =~ /^https?:\/\/[\S]+$/
      accept = content_type == "text/plain" ? "*/*" : content_type
      result = http_request("GET", body, accept, {}, nil, false)
      unless result.status == 200
        raise Exception, "Error adding data from remote URL #{body} => #{result.status} : #{result}"
      end
      body = result.body
    end

    http_request("POST", "#{database}/#{transaction_id}/add", "*/*", params, body, false, content_type, nil)
  end
end

Stardog::Connection.prepend(StardogFileCompatibility) unless File.respond_to?(:exists?)

include Stardog

# sd_url = 'http://localhost:5820/'
sd_url = 'http://ep.pubannotation.org/'
sd_database = 'PubAnnotation'
sd_user = 'anonymous'
sd_password = 'anonymous'

Pubann::Application.config.sd = stardog(sd_url, user: sd_user, password: sd_password, reasoning: :sl)
Pubann::Application.config.db = sd_database
