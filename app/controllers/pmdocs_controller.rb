class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:annset_id]
      @annset = Annset.find_by_name(params[:annset_id])
      if @annset
        @docs = @annset.docs.keep_if{|d| d.sourcedb == 'PubMed' and d.serial == 0}.paginate(:page => params[:page])
        #@docs = annset.docs.where(:sourcedb => 'PubMed', :serial => 0).uniq.paginate(:page => params[:page])
      else
        @doc = nil
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
      end
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
          unless @doc.annsets.include?(@annset)
            @annset.docs << @doc
            notice = "The document, #{@doc.sourcedb}:#{@doc.sourceid}, was added to the annotation set, #{@annset.name}."
          end
        else
          @doc = get_pmdoc(params[:id])
          if @doc
            @annset.docs << @doc
            notice = "The document, PubMed:#{params[:id]}, was created and added to the annotation set, #{params[:annset_id]}."
          else
            notice = "The document, PubMed:#{params[:id]}, could not be created." 
          end
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
        @doc = nil
      end
    else
      @doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      if @doc
        @annsets = @doc.annsets
      else
        @doc = get_pmdoc(params[:id])
        if @doc
          notice = "The document, PubMed:#{params[:id]}, was created." 
        else
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

        format.html {
          flash[:notice] = notice
          render 'docs/show'
        }
        format.json { render json: @doc }
      else 
        format.html { redirect_to pmdocs_url, notice: notice}
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end


  # PUT /pmdocs/:pmid
  # PUT /pmdocs/:pmid.json
  def update
    doc    = nil
    annset = nil

    if params[:annset_id]
      annset = Annset.find_by_name(params[:annset_id])
      if annset
        doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
        if doc
          unless doc.annsets.include?(annset)
            annset.docs << doc
            notice = "The document, #{@doc.sourcedb}:#{@doc.sourceid}, was added to the annotation set, #{annset.name}."
          end
        else
          doc = get_pmdoc(params[:id])
          if doc
            annset.docs << doc
            notice = "The document, #{@doc.sourcedb}:#{@doc.sourceid}, was created in the annotation set, #{annset.name}."
          else
            notice = "The document, PubMed:#{params[:id]}, could not be created." 
          end
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
        doc = nil
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      unless doc
        doc = get_pmdoc(params[:id])
        if doc
          notice = "The document, PubMed:#{params[:id]}, was successfuly created." 
        else
          notice = "The document, PubMed:#{params[:id]}, could not be created." 
        end
      end
    end

    respond_to do |format|
      format.html {
        if annset
          redirect_to annset_pmdocs_path(annset.name), notice: notice
        else
          redirect_to pmdocs_path, notice: notice
        end
      }

      format.json {
        if doc and (annset or !params[:annset_id])
          head :no_content
        else
          head :unprocessable_entity
        end
      }
    end
  end

  # DELETE /pmdocs/:pmid
  # DELETE /pmdocs/:pmid.json
  def destroy
    annset = nil

    if params[:annset_id]
      annset = Annset.find_by_name(params[:annset_id])
      if annset
        doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
        if doc
          if doc.annsets.include?(annset)
            annset.docs.delete(doc)
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was removed from the annotation set, #{annset.name}."
          else
            notice = "the annotation set, #{annset.name} does not include the document, #{doc.sourcedb}:#{doc.sourceid}."
          end
        else
          notice = "The document, PubMed:#{params[:id]}, does not exist in PubAnnotation." 
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not exist."
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      doc.destroy
    end

    respond_to do |format|
      format.html {
        if annset
          redirect_to annset_pmdocs_path(annset.name), notice: notice
        else
          redirect_to pmdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
    end
  end

end
