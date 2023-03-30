Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://textae.pubannotation.org', 'http://localhost:3000'

    # credentials (boolean, default: false): Sets the Access-Control-Allow-Credentials response header.
    resource '*', methods: :any, headers: :any, credentials: true
  end
end