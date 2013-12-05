class Documentation < ActiveRecord::Base
  belongs_to :documentation_category
  
  attr_accessible :title, :body, :documentation_category_id
  
  def self.maintainable_for?(current_user)
    current_user.present? && current_user.id > 0
  end
end