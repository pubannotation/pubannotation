class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:annset_id]
      @annset, notice = find_annset(params[:annset_id])
      if @annset
        @docs = @annset.docs.where(:sourcedb => 'PMC', :serial => 0)
      else
        @doc = nil
      end
    else
      @docs = Doc.where(:sourcedb => 'PMC', :serial => 0)
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

  # GET /pmcdocs/:pmcdoc_id
  # GET /pmcdocs/:pmcdoc_id.json
  def show
    if (params[:annset_id])
      annset, notice = find_annset(params[:annset_id])
      if annset
        divs, notice = find_pmcdoc(params[:id], annset)
      else
        divs = nil
      end
    else
      divs, notice = find_pmcdoc(params[:id])
    end

    respond_to do |format|
      format.html {
        if divs
          if annset
            redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
          else
            redirect_to pmcdoc_divs_path(params[:id]), :notice => notice
          end
        else
          if annset
            redirect_to annset_pmcdocs_path(params[:annset_id]), :notice => notice
          else
            redirect_to pmcdocs_path, :notice => notice
          end
        end
      }
      format.json {
        if divs
          render json: divs
        else
          head :unprocessable_entity
        end
      }
    end
  end
end
