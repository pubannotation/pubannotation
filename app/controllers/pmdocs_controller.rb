class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:annset_id] and @annset = Annset.find_by_name(params[:annset_id])
      @docs = @annset.docs.uniq.keep_if{|d| d.sourcedb == 'PubMed' and d.serial == 0}.paginate(:page => params[:page])
#      @docs = annset.docs.where(:sourcedb => 'PubMed', :serial => 0).uniq.paginate(:page => params[:page])
    else
      @docs = Doc.where(:sourcedb => 'PubMed', :serial => 0).paginate(:page => params[:page])
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /pmdocs/:pmid
  # GET /pmdocs/:pmid.json
  def show

    if params[:annset_id] 
      @annset = Annset.find_by_name(params[:annset_id])
      if @annset
        @doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
        if @doc
          annsets = @doc.annsets.uniq
          unless annsets.include?(@annset)
            notice = "The document, #{@doc.sourcedb}:#{@doc.sourceid}, does not belong to the annotation set, #{@annset.name}."
            @doc = nil
          end
        else
          notice = "The annotation set, #{params[:annset_id]}, does not have an annotation to the document, PubMed:#{params[:id]}."
          @doc = nil
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
        @doc = nil
      end
    else
      @doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      if @doc
        @annsets = @doc.annsets.uniq
      else
        @doc = get_pmdoc(params[:id])
        unless @doc
          notice = "The document, PubMed:#{params[:id]}, could not be created." 
        end
      end
    end

    respond_to do |format|
      if @doc

        @text = @doc.body
        if (params[:encoding] == 'ascii')
          asciitext = get_ascii_text(@text)
            @text = asciitext
        end

        format.html { render 'docs/show' } # show.html.erb
        format.json { render json: @doc }
      else 
        format.html { redirect_to pmdocs_url, notice: notice}
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end


  def create
    @doc = get_pmdoc(params[:id]) 
    
    respond_to do |format|
      if @doc
        format.html { redirect_to pmdoc_path(params[:id]), notice: 'Pubmed document was successfully created.' }
        format.json { render json: @doc, status: :created, location: @doc }
      else
        format.html { redirect_to pmdocs_path, notice: 'Pubmed document could not be created.' }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

end
