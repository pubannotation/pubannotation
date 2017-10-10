require 'stardog'
include Stardog

sd_url = 'http://localhost:5820/'
sd_database = 'PubAnnotation'
sd_user = 'anonymous'
sd_password = 'anonymous'


Pubann::Application.config.sd = stardog(sd_url, user: sd_user, password: sd_password, reasoning: :sl)
Pubann::Application.config.db = sd_database
Pubann::Application.config.namespaces = {
	owl: 'http://www.w3.org/2002/07/owl#',
	rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
	rdfs: 'http://www.w3.org/2000/01/rdf-schema#',
	xsd: 'http://www.w3.org/2001/XMLSchema#',
	tao: 'http://pubannotation.org/ontology/tao.owl#',
	prj: 'http://pubannotation.org/projects/'
}
