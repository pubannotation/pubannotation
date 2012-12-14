class HomeController < ApplicationController
  def index
  	@docs_num = Doc.where(:serial => 0).length
  	@pmdocs_num = Doc.where(:sourcedb => 'PubMed', :serial => 0).length
  	@pmcdocs_num = Doc.where(:sourcedb => 'PMC', :serial => 0).length
  	@annsets_num = find_annsets.length
  end
end
