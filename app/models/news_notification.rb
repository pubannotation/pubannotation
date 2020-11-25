class NewsNotification < ActiveRecord::Base
	attr_accessible :title, :body, :category, :active
	validates_presence_of :title, :body
	default_scope order: 'updated_at DESC'
	scope :active, where(active: true)
end
