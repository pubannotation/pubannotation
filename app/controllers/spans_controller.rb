class SpansController < ApplicationController
  def sql
    if params[:sql].present?
      sanitized_sql = ActiveRecord::Base::sanitize(params[:sql]).gsub('\'', '')
      @results = Denotation.connection.execute(sanitized_sql)
      @results = @results.paginate(:page => params[:page], :per_page => 50)
      @doc_ids = @results.collect{|result| result['doc_id']}.uniq
      @docs = Doc.find(@doc_ids)
    end
  end
end