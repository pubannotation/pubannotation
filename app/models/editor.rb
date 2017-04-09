class Editor < ActiveRecord::Base
	extend FriendlyId
  friendly_id :name

  belongs_to :user
  attr_accessible :description, :home, :is_public, :name, :parameters, :url

  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

  validates :url, :presence => true

  serialize :parameters, Hash

  scope :accessibles, -> (current_user) {
    if current_user.present?
      where("is_public = true or user_id = #{current_user.id}")
    else
      where(is_public: true)
    end
  }

end
