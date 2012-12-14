class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:annset_id]
      @annset, notice = find_annset(params[:annset_id])
      if @annset
        @docs = @annset.docs.where(:sourcedb => 'PubMed', :serial => 0)
      else
        @docs = nil
      end
    else
      @docs = Doc.where(:sourcedb => 'PubMed', :serial => 0)
    end

    @docs = @docs.sort{|a, b| a.sourceid.to_i <=> b.sourceid.to_i}
    @docs = @docs.paginate(:page => params[:page])

    respond_to do |format|
      if @docs
        format.html
        format.json { render json: @docs }
      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
      end
    end
  end

  # GET /pmdocs/:pmid
  # GET /pmdocs/:pmid.json
  def show
    if (params[:annset_id])
      @annset, notice = find_annset(params[:annset_id])
      if @annset
        @doc, notice = find_pmdoc(params[:id], @annset)
      else
        @doc = nil
      end
    else
      @doc, notice = find_pmdoc(params[:id])
      @annsets = find_annsets(@doc)
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
        format.json { head :unprocessable_entity }
      end
    end
  end

  # POST /pmdocs
  # POST /pmdocs.json
  def create
    num_created, num_added, num_failed = 0, 0, 0

    if (params[:annset_id])
      annset, notice = find_annset(params[:annset_id])
      if annset
        pmids = params[:pmids].split(/[ ,"':|\t\n]+/)
        pmids.each do |sourceid|
          doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
          if doc
            unless annset.docs.include?(doc)
              annset.docs << doc
              num_added += 1
            end
          else
            doc = get_pmdoc(sourceid)
            if doc
              annset.docs << doc
              num_added += 1
            else
              num_failed += 1
            end
          end
        end
        notice = "#{num_added} documents were added to the document set, #{annset.name}."
      end
    else
      notice = "Annotation set is not specified."
    end

    respond_to do |format|
      if num_created + num_added + num_failed > 0
        format.html { redirect_to annset_pmdocs_path(annset.name), :notice => notice }
        format.json { render status: :created, location: annset_pmdocs_path(annset.name) }
      else
        format.html { redirect_to home_path, :notice => notice }
        format.json { head :unprocessable_entity }
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
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was added to the annotation set, #{annset.name}."
          end
        else
          doc = get_pmdoc(params[:id])
          if doc
            annset.docs << doc
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was created in the annotation set, #{annset.name}."
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
          redirect_to annset_pmdocs_path(annset.name), :notice => notice, :method => :get
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
          redirect_to annset_pmdocs_path(annset.name), :notice => notice
        else
          redirect_to pmdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
    end
  end

end
