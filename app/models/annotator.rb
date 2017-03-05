class Annotator < ActiveRecord::Base
	extend FriendlyId

  belongs_to :user
  attr_accessible :abbrev, :description, :home, :method, :name, :params, :url

  friendly_id :abbrev
  validates_format_of :abbrev, :with => /\A[a-z0-9]+\z/i

  serialize :params, Hash
  serialize :params2, Hash

  def editable?(current_user)
    if current_user.present?
      self.user == current_user
    else
      false
    end
  end
end
