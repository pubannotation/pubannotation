class NewsNotification < ActiveRecord::Base
	validates_presence_of :title, :body
	default_scope order: 'updated_at DESC'
	scope :active, where(active: true)
end
