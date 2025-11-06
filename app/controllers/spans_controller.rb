class SpansController < ApplicationController
  include SpansHelper

  def doc_spans_index
    begin
      @doc = Doc.find_by!(sourcedb:params[:sourcedb], sourceid:params[:sourceid])
      @doc.set_ascii_body if params[:encoding] == 'ascii'

      @spans_index = Denotation.where(doc: @doc)
                               .as_json
                               .uniq{ _1[:span] }
                               .map{ to_span _1 }

      respond_to do |format|
        format.html {render 'spans_index'}
        format.json {render json: {text: @doc.body, denotations: @spans_index}}
      end
    rescue => e
      Rails.logger.error e.message

      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def project_doc_spans_index
    begin
      @project = Project.accessible(current_user).find_by!(name: params[:project_id])

      @doc = @project.docs.find_by!(sourcedb:params[:sourcedb], sourceid:params[:sourceid])
      @doc.set_ascii_body if params[:encoding] == 'ascii'

      @spans_index = Denotation.where(doc: @doc)
                               .where(project: @project)
                               .as_json
                               .uniq{ _1[:span] }
                               .map{ to_span _1 }

      respond_to do |format|
        format.html {render 'spans_index'}
        format.json {render json: {text: @doc.body, denotations: @spans_index}}
      end
    rescue => e
      Rails.logger.error e.message

      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end
  
  def sql
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

  def get_url
    # Validate parameters first before fetching document
    raise ArgumentError, "The 'text' parameter is missing." unless params[:text].present?
    raise ArgumentError, "The value of the 'text' parameter is not a string." unless params[:text].class == String

    text = params[:text].strip

    # Find or fetch the document
    doc = Doc.find_by sourcedb:params[:sourcedb], sourceid:params[:sourceid] \
            || Doc.sequence_and_store_doc!(params[:sourcedb], params[:sourceid])

    # Use TextAlignment to find the text in the document
    aligner = TextAlignment::TextAlignment.new(doc.body)
    result = aligner.align(text)

    raise ArgumentError, "Text alignment failed." unless result && result[:blocks]

    # Find the first block that successfully aligned (not :empty)
    # The block contains the source (input text) and target (document) positions
    aligned_block = result[:blocks].find { |block| block[:alignment] != :empty && block[:target] }

    raise ArgumentError, "Text could not be found in the document." unless aligned_block

    span = {
      begin: aligned_block[:target][:begin],
      end: aligned_block[:target][:end]
    }

    annotations = {
      text: text,
      sourcedb: params[:sourcedb],
      sourceid: params[:sourceid],
      denotations:[{
          span:,
          obj:'span'
      }]
    }
    url = "#{home_url}docs/sourcedb/#{annotations[:sourcedb]}/sourceid/#{annotations[:sourceid]}/spans/#{span[:begin]}-#{span[:end]}"

    respond_to do |format|
      format.any do
        render plain: url,
               status: :created,
               location: url
      end
    end
  rescue => e
    respond_to do |format|
      format.html {render plain: e.message, status: :unprocessable_entity}
      format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    end
  end

  private

  def to_span(denotation)
    {
      id: denotation[:id],
      span: denotation[:span],
      obj: self.span_url(@doc, denotation[:span])
    }
  end
end
