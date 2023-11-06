# for TAO RDF indexing
# Pubann::Application.config.ep_url = 'http://localhost:5820/'
Pubann::Application.config.ep_url = 'https://ep.pubannotation.org/sparql'
Pubann::Application.config.ep_database = 'PubAnnotation'
Pubann::Application.config.ep_user = 'user'
Pubann::Application.config.ep_password = 'password'
Pubann::Application.config.project_indexable_max_docs = 200000

Pubann::Application.config.system_path_rdf = "#{Rails.root}/db/rdf/"
Pubann::Application.config.project_indexable_max_docs = 200000

Pubann::Application.config.namespaces = {
	owl: 'http://www.w3.org/2002/07/owl#',
	rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
	rdfs: 'http://www.w3.org/2000/01/rdf-schema#',
	xsd: 'http://www.w3.org/2001/XMLSchema#',
	pubann: 'http://pubannotation.org/ontology/pubannotation.owl#'
	tao: 'http://pubannotation.org/ontology/tao.owl#',
	prj: 'http://pubannotation.org/projects/'
}
