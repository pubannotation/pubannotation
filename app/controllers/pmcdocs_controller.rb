class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:annset_id] and @annset = Annset.find_by_name(params[:annset_id])
      @docs = @annset.docs.where(:sourcedb => 'PMC', :serial => 0).uniq.paginate(:page => params[:page])
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
    annset = nil
    doc = nil

    if params[:annset_id]
      puts "-=-=-=-=-=-=-=-=-0"
      annset = Annset.find_by_name(params[:annset_id])
      if annset
        doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:id], 0)
        puts "-=-=-=-=-=-=-=-=-3"

        if doc
          puts "-=-=-=-=-=-=-=-=-4"

          unless doc.annsets.include?(@annset)
            puts "-=-=-=-=-=-=-=-=-5"
            annset.docs << doc
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was added to the annotation set, #{annset.name}."
          end
          redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
        else
          doc = get_pmcdoc(params[:id])
          if doc
            annset.docs << @doc
            notice = "The document, PMC:#{params[:id]}, was created in the annotation set, #{params[:annset_id]}."
            redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
          else
            notice = "The document, PMC:#{params[:id]}, could not be created." 
            redirect_to annset_pmcdocs_path(params[:annset_id]), :notice => notice
          end
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
        doc = nil
        redirect_to home_path, :notice => notice
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:id], 0)
      unless doc
        doc = get_pmcdoc(params[:id])
        if doc
          notice = "The document, PMC:#{params[:id]}, was created." 
        else
          notice = "The document, PMC:#{params[:id]}, could not be created." 
        end
      end
    end

    respond_to do |format|
      if annset
        if doc
          format.html { redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice }
          format.json { render json: @doc }
        else
          format.html { redirect_to annset_pmcdocs_path(params[:annset_id]), :notice => notice }
          format.json { render json: @doc }
        end
      else 
        if doc
          format.html { redirect_to pmcdoc_divs_path(params[:id]), :notice => notice }
          format.json { render json: @doc.errors, status: :unprocessable_entity }
        else
          format.html { redirect_to home_path, :notice => notice }
          format.json { render json: @doc.errors, status: :unprocessable_entity }
        end
      end
    end
  end

end
