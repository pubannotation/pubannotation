class Documentation < ActiveRecord::Base
  belongs_to :documentation_category
  
  attr_accessible :title, :body, :documentation_category_id
end