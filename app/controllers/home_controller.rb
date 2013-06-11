class HomeController < ApplicationController
  def index
  	@docs = Doc.where(:serial => 0)
  	@pmdocs = Doc.where(:sourcedb => 'PubMed', :serial => 0)
  	@pmcdocs = Doc.where(:sourcedb => 'PMC', :serial => 0)
  	@projects = get_projects
  end
end
