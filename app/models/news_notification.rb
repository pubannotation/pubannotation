class NewsNotification < ActiveRecord::Base
  attr_accessible :title, :body, :category
  validates_presence_of :title, :body
  default_scope order: 'updated_at DESC'
end
