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
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def div_spans_index
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @doc.set_ascii_body if params[:encoding] == 'ascii'
      @spans_index = @doc.spans_index

      respond_to do |format|
        format.html {render 'spans_index'}
        format.json {render json: {text: @doc.body, denotations: @spans_index}}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
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

      @doc = @project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], params[:divid])
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
        @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

        get_docs_projects

        @annotations = @doc.hannotations(@projects, @span)

        @project_annotations_index = if @annotations[:denotations].present?
          {@annotations[:project] => @annotations}
        elsif @annotations[:tracks].present?
          @annotations[:tracks].inject({}){|index, track| index[track[:project]] = track; index}
        else
          {}
        end

        @projects.delete_if{|project| !@project_annotations_index.keys.include?(project.name)}

        # @annotations_projects_check = true
        @annotations_path = "#{url_for(:only_path => true)}/annotations"

        if @annotations[:tracks].present?
          @annotations[:denotations] = @annotations[:tracks].inject([]){|denotations, track| denotations += (track[:denotations] || [])}
          @annotations[:relations] = @annotations[:tracks].inject([]){|relations, track| relations += (track[:relations] || [])}
          @annotations[:modifications] = @annotations[:tracks].inject([]){|modifications, track| modifications += (track[:modifications] || [])}
        end

        respond_to do |format|
          format.html {render 'docs/show'}
          format.json {render json: @doc.to_hash}
          format.txt  {render text: @doc.body}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  def div_span_show
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @span = {:begin => params[:begin].to_i, :end => params[:end].to_i}

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @content = @doc.highlight_span(@span).gsub(/\n/, "<br>")

      get_docs_projects

      @annotations = @doc.hannotations(@projects, @span)

      @project_annotations_index = if @annotations[:denotations].present?
        {@annotations[:project] => @annotations}
      elsif @annotations[:tracks].present?
        @annotations[:tracks].inject({}){|index, track| index[track[:project]] = track; index}
      else
        {}
      end

      @projects.delete_if{|project| !@project_annotations_index.keys.include?(project.name)}

      # @annotations_projects_check = true
      @annotations_path = "#{url_for(:only_path => true)}/annotations"

      if @annotations[:tracks].present?
        @annotations[:denotations] = @annotations[:tracks].inject([]){|denotations, track| denotations += (track[:denotations] || [])}
        @annotations[:relations] = @annotations[:tracks].inject([]){|relations, track| relations += (track[:relations] || [])}
        @annotations[:modifications] = @annotations[:tracks].inject([]){|modifications, track| modifications += (track[:modifications] || [])}
      end

      respond_to do |format|
        format.html {render 'docs/show'}
        format.txt  {render text: @annotations[:text]}
        format.json {render json: {text: @annotations[:text]}}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
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
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def project_div_span_show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
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
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
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
        @denotations = @denotations.page(params[:page]).per(50)
      end
    rescue => error
      flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
    end
  end

  def get_url
    if params[:divid].present?
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      unless doc.present?
        divs = Doc.import_from_sequence(params[:sourcedb], params[:sourceid])
        raise IOError, "Failed to get the document" unless divs.present?
        expire_fragment("sourcedb_counts")
        expire_fragment("count_#{params[:sourcedb]}")
        doc = divs[params[:divid]]
      end
    else
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      unless divs.present?
        divs = Doc.import_from_sequence(params[:sourcedb], params[:sourceid])
        raise IOError, "Failed to get the document" unless divs.present?
        expire_fragment("sourcedb_counts")
        expire_fragment("count_#{params[:sourcedb]}")
      end
      doc = divs[0] if divs.length == 1
    end

    url = if params[:text]
      text = params[:text].strip
      annotations = {
        text: text,
        sourcedb: params[:sourcedb],
        sourceid: params[:sourceid],
        denotations:[{span:{begin:0, end:text.length}, obj:'span'}]
      }

      annotations = if doc.present?
        Annotation.prepare_annotations(annotations, doc)
      elsif divs.present?
        Annotation.prepare_annotations_divs(annotations, divs).select{|ann| ann[:denotations].present?}.first
      else
        raise "Could not find the document."
      end

      raise "Could not find the string in the specified document." if annotations.nil?

      res  = "#{home_url}/docs/sourcedb/#{annotations[:sourcedb]}/sourceid/#{annotations[:sourceid]}"
      res += "/divs/#{annotations[:divid]}" if annotations[:divid].present?

      span = annotations[:denotations].first[:span]
      res += "/spans/#{span[:begin]}-#{span[:end]}"
    else
      res  = "#{home_path}/docs/sourcedb/#{annotations[:sourcedb]}/sourceid/#{annotations[:sourceid]}"
      res += "/divs/#{annotations[:divid]}" if annotations[:divid].present?
    end

    respond_to do |format|
      format.html {render text: url, status: :created, location: url}
      format.json {render text: url, status: :created, location: url}
      format.txt  {render text: url, status: :created, location: url}
    end
  rescue => e
    respond_to do |format|
      format.html {render text: e.message, status: :unprocessable_entity}
      format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      format.txt  {render text: e.message, status: :unprocessable_entity}
    end
  end
end