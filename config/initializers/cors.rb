Rails.application.config.middleware.insert_before 0, Rack::Cors do
	allow do
		origins do |source, env|
			source unless source == 'null'
		end
		resource '*', methods: :any, headers: :any, credentials: true
	end
end
