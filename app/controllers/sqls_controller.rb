class SqlsController < ApplicationController
	require 'json'
	
	def index
		# TODO
		# filter => limit users who can execute this action
		# limit commands => ex: DROP TABLE, DELETE, UPDATE
		if params[:sql].present?
			sanitized_sql =  sanitize_sql(params[:sql])
			@results = ActiveRecord::Base.connection.execute(sanitized_sql).to_a
			@results = @results.page(params[:page])
		end
	end

	private

	def sanitize_sql(sql)
		# sanitized_sql = ActiveRecord::Base::sanitize(params[:sql])#.gsub('\'', '')
		sql.gsub("\"", '\'')
	end
end