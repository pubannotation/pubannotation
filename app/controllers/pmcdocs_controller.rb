class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:annset_id]
      @annset = Annset.find_by_name(params[:annset_id])
      if @annset
        @docs = @annset.docs.where(:sourcedb => 'PMC', :serial => 0).paginate(:page => params[:page])
      else
        @doc = nil
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
      end
    else
      @docs = Doc.where(:sourcedb => 'PMC', :serial => 0).paginate(:page => params[:page])
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /pmcdocs/:pmcdoc_id
  # GET /pmcdocs/:pmcdoc_id.json
  def show
    if params[:annset_id]
      annset = Annset.find_by_name(params[:annset_id])
      if annset
        doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:id], 0)
        if doc
          unless doc.annsets.include?(annset)
            annset.docs << doc
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was added to the annotation set, #{annset.name}."
          end
          redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
        else
          divs = get_pmcdoc(params[:id])
          if divs
            divs.each {|div| annset.docs << div}
            notice = "The document, PMC:#{params[:id]}, was created in the annotation set, #{params[:annset_id]}."
            redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
          else
            notice = "The document, PMC:#{params[:id]}, could not be created." 
            redirect_to annset_pmcdocs_path(params[:annset_id]), :notice => notice
          end
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
        redirect_to pmcdocs_path, :notice => notice
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:id], 0)
      if doc
        redirect_to pmcdoc_divs_path(params[:id])
      else
        divs = get_pmcdoc(params[:id])
        if divs
          notice = "The document, PMC:#{params[:id]}, was created in PubAnnotation." 
          redirect_to pmcdoc_divs_path(params[:id]), :notice => notice
        else
          notice = "The document, PMC:#{params[:id]}, could not be created." 
          redirect_to pmcdocs_path, :notice => notice
        end
      end
    end
  end

end
