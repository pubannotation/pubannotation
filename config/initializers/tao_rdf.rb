# for TAO RDF indexing
# Pubann::Application.config.ep_url = 'http://localhost:5820/'
Pubann::Application.config.ep_url = 'https://ep.pubannotation.org/PubAnnotation/query'
Pubann::Application.config.ep_database = 'PubAnnotation'
Pubann::Application.config.ep_user = 'user'
Pubann::Application.config.ep_password = 'password'
Pubann::Application.config.project_indexable_max_docs = 200000

Pubann::Application.config.system_path_rdf = "#{Rails.root}/db/rdf/"
Pubann::Application.config.project_indexable_max_docs = 200000
