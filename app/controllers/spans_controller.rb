class SpansController < ApplicationController

  def doc_spans_index
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @spans_index = @doc.spans_index

        respond_to do |format|
          format.html {render 'spans_index'}
          format.json {render json: {text: @doc.body, denotations: @spans_index}}
        end
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def div_spans_index
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:div_id])
      raise "There is no such document." unless @doc.present?

      @doc.set_ascii_body if params[:encoding] == 'ascii'
      @spans_index = @doc.spans_index

      respond_to do |format|
        format.html {render 'spans_index'}
        format.json {render json: {text: @doc.body, denotations: @spans_index}}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def project_doc_spans_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @spans_index = @doc.spans_index(@project)

        respond_to do |format|
          format.html {render 'spans_index'}
          format.json {render json: {text: @doc.body, denotations: @spans_index}}
        end
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def project_div_spans_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @doc = @project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], params[:div_id])
      raise "There is no such document in the project." unless @doc.present?

      @doc.set_ascii_body if params[:encoding] == 'ascii'
      @spans_index = @doc.spans_index(@project)

      respond_to do |format|
        format.html {render 'spans_index'}
        format.json {render json: {text: @doc.body, denotations: @spans_index}}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def doc_span_show
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]
        @span = {:begin => params[:begin].to_i, :end => params[:end].to_i}

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @annotations = @doc.hannotations(nil, @span)
        @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

        @project_annotations_index = if @annotations[:denotations].present?
          {@annotations[:project] => @annotations}
        elsif @annotations[:tracks].present?
          @annotations[:tracks].inject({}){|index, track| index[track[:project]] = track; index}
        end

        @projects = @project_annotations_index.keys.map{|p| Project.find_by_name(p)}

        @annotations_projects_check = true
        @annotations_path = "#{url_for(:only_path => true)}/annotations"

        respond_to do |format|
          format.html {render 'docs/show'}
          format.json {render json: @doc.to_hash}
          format.txt  {render text: @doc.body}
        end
      end

    # rescue => e
    #   respond_to do |format|
    #     format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : docs_path), notice: e.message}
    #     format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    #     format.txt  {render text: message, status: :unprocessable_entity}
    #   end
    end
  end

  def div_span_show
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:div_id])
      raise "There is no such document in the project." unless @doc.present?

      @span = {:begin => params[:begin].to_i, :end => params[:end].to_i}

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @annotations = @doc.hannotations(@project, @span)
      @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

      p @annotations
      puts "====="

      @project_annotations_index = if @annotations[:denotations].present?
        {@annotations[:project] => @annotations}
      elsif @annotations[:tracks].present?
        @annotations[:tracks].inject({}){|index, track| index[track[:project]] = track; index}
      else
        {}
      end

      @projects = @project_annotations_index.keys.map{|p| Project.find_by_name(p)}

      @annotations_projects_check = true
      @annotations_path = "#{url_for(:only_path => true)}/annotations"

      respond_to do |format|
        format.html {render 'docs/show'}
        format.txt  {render text: @annotations[:text]}
        format.json {render json: {text: @annotations[:text]}}
      end
    # rescue => e
    #   respond_to do |format|
    #     format.html {redirect_to docs_path, notice: e.message}
    #     format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    #     format.txt  {render status: :unprocessable_entity}
    #   end
    end
  end

  def project_doc_span_show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])}
        end
      else
        @doc = divs[0]
        @span = {:begin => params[:begin].to_i, :end => params[:end].to_i}

        @doc.set_ascii_body if (params[:encoding] == 'ascii')
        @annotations = @doc.hannotations(@project, @span)
        @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

        respond_to do |format|
          format.html {render 'docs/show_in_project'}
          format.txt  {render text: @annotations[:text]}
          format.json {render json: {text: @annotations[:text]}}
        end
      end
    # rescue => e
    #   respond_to do |format|
    #     format.html {redirect_to project_docs_path(@project.name), notice: e.message}
    #     format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    #     format.txt  {render status: :unprocessable_entity}
    #   end
    end
  end

  def project_div_span_show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:div_id])
      raise "There is no such document in the project." unless @doc.present?

      @span = {:begin => params[:begin].to_i, :end => params[:end].to_i}

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @annotations = @doc.hannotations(@project, @span)
      @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

      respond_to do |format|
        format.html {render 'docs/show_in_project'}
        format.txt  {render text: @annotations[:text]}
        format.json {render json: {text: @annotations[:text]}}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : docs_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def span_show2
    @doc = nil if @project.present? && @doc.projects.include?(@project.id)

    sourcedb, sourceid, serial, id = get_docspec(params)
    span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil
 
    if @doc.present?
      if @project.present?
        @project_denotations = @doc.denotations_in_tracks(@project, span)
      end
    else
      @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial)
      sort_order = sort_order(Project)
      @projects = Project.id_in(@doc.projects_within_span(span)).collect{|project| project.id}.sort_by_params(sort_order)
      if @doc.present? && @projects.present?
        @project_denotations = @doc.denotations_in_tracks(@projects, span)
      end
      @annotations_projects_check = true
    end
    @spans, @prev_text, @next_text = @doc.spans(params)
    @text = @doc.text(params)
    @highlight_text = @doc.spans_highlight(params)
    respond_to do |format|
      format.html {render 'docs/spans'}
      format.txt  {render text: @text}
      format.json { 
        if @project_denotations.present?
          @denotations = Array.new
          @project_denotations.each do |project_denotation|
            if project_denotation[:denotations].present?
              project_denotation[:denotations].each do |denotation|
                @denotations << denotation.select{|key| key == :span}
              end
            end
          end
        end
        json_hash = {text: @text}
        json_hash[:focus] = get_focus({params: params}) if params[:context_size].present?
        render json: json_hash
      }
      format.csv { 
        send_data @doc.to_csv(params)
      }
    end
  end
  
  def sql
    begin
      @search_path = spans_sql_path
      if params[:project_id].present?
        # when search from inner project
        project = Project.find_by_name(params[:project_id])
        if project.present?
          @search_path = project_spans_sql_path
        else
          redirect_to @search_path
        end
      end
      @denotations = Denotation.sql_find(params, current_user, project ||= nil)
      if @denotations.present?
        @denotations = @denotations.paginate(:page => params[:page], :per_page => 50)
      end
    rescue => error
      flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
    end
  end
end