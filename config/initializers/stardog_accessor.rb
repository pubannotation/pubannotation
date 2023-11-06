require 'stardog'
include Stardog

# sd_url = 'http://localhost:5820/'
sd_url = 'http://ep.pubannotation.org/'
sd_database = 'PubAnnotation'
sd_user = 'anonymous'
sd_password = 'anonymous'

Pubann::Application.config.sd = stardog(sd_url, user: sd_user, password: sd_password, reasoning: :sl)
Pubann::Application.config.db = sd_database
