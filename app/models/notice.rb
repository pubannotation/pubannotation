class Notice < ActiveRecord::Base
  belongs_to :project
  attr_accessible :successful, :method, :uri, :message

  def result
    successful == true ? 'successful' : 'unsuccessful'
  end
end
