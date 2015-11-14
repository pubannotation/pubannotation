class Message < ActiveRecord::Base
  belongs_to :job
  attr_accessible :item, :body
end
