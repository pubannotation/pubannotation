require 'zip/zip'

class Denotation < ActiveRecord::Base
	include RangeConcern
	include DenotationsHelper

	belongs_to :project
	belongs_to :doc

	has_many :attrivutes, :as => :subj, :dependent => :destroy
	has_many :modifications, :as => :obj, :dependent => :destroy

	has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
	has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

	validates :hid,        presence: true
	validates :begin,      presence: true, numericality: {only_integer: true}
	validates :end,        presence: true, numericality: {only_integer: true}
	validates :obj,        presence: true
	validates :project_id, presence: true
	validates :doc_id,     presence: true

	scope :accessible_projects, lambda{|current_user_id|
		joins([:project, :doc]).
		where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
	}
	
	scope :sql, lambda{|ids|
		where('denotations.id IN(?)', ids).
		order('denotations.id ASC') 
	}
	
	after_create :increment_numbers, :update_project_updated_at
	after_update :update_project_updated_at
	after_destroy :decrement_numbers, :update_project_updated_at

	def to_s
		"#{self.project.name}:[#{self.begin}, #{self.end}]"
	end

	def span
		[self.begin, self.end]
	end

	def as_json(options={})
		{
			id: hid,
			span: {begin: self.begin, end: self.end},
			obj: obj
		}
	end

	def get_hash
		hdenotation = Hash.new
		hdenotation[:id]   = hid
		hdenotation[:span] = {:begin => self.begin, :end => self.end}
		hdenotation[:obj]  = obj
		hdenotation
	end

	def range_valid?(max_offset)
		self.begin.is_a?(Integer) && self.end.is_a?(Integer) && self.begin >= 0 && self.end > self.begin && self.end <= max_offset
	end

	# after save
	def update_project_updated_at
		self.project.update_updated_at
	end

	def increment_project_denotations_num
		self.project.increment!(:denotations_num)
	end

	def decrement_project_denotations_num
		self.project.decrement!(:denotations_num)
	end

	def increment_numbers
		pd = ProjectDoc.find_by_project_id_and_doc_id(self.project.id, self.doc.id)
		pd.increment!(:denotations_num) if pd
		self.doc.increment!(:denotations_num)
		self.project.increment!(:denotations_num)
	end

	def decrement_numbers
		pd = ProjectDoc.find_by_project_id_and_doc_id(self.project.id, self.doc.id)
		pd.decrement!(:denotations_num) if pd
		self.doc.decrement!(:denotations_num)
		self.project.decrement!(:denotations_num)
	end

	def self.new_id_init(to_avoid = nil)
		@to_avoid = to_avoid
		@idnum = 0
	end

	def self.new_id
		loop do
			@idnum += 1
			_id = 'T' + @idnum.to_s
			break _id if !@to_avoid || !@to_avoid.include?(_id)
		end
	end

	def self.sql_find(params, current_user, project)
		if params[:sql].present?
			current_user_id = current_user.present? ? current_user.id : nil
			sanitized_sql = sanitize_sql(params[:sql])
			results = self.connection.execute(sanitized_sql, :includes => [:project])
			if results.present?
				ids = results.collect{|result| result['id']}
				denotations = self.accessible_projects(current_user_id).in_project(project.id).sql(ids)
			end       
		end
	end

	def self.find_a_denotation(project, sourcedb, sourceid, hid)
		doc = Doc.where(sourcedb:sourcedb, sourceid:sourceid).first
		where(doc_id:doc.id, project_id:project.id, hid:hid).first
	end

	def self.get_span_url_by_hid(project, sourcedb, sourceid, hid)
		doc = Doc.where(sourcedb:sourcedb, sourceid:sourceid).first
		d = where(doc_id:doc.id, project_id:project.id, hid:hid).first
		return nil if d.nil?
		Rails.application.routes.url_helpers.span_show_project_sourcedb_sourceid_docs_url(project.name, sourcedb, sourceid, d.begin, d.end)
	end
end
