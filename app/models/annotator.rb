class Annotator < ActiveRecord::Base
	extend FriendlyId

  belongs_to :user
  attr_accessible :name, :description, :home, :url, :method, :payload, :batch_num, :is_public

  friendly_id :name
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
  validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

  validates :url, :presence => true
  validates :method, :presence => true
  validates :payload, :presence => true, if: 'method == 1'
  validates :batch_num, :presence => true
  validates :batch_num, :numericality => { equal_to: 0 }, if: Proc.new{|a| a.payload.present? && a.payload['_body_'] == '_text_'}

  serialize :payload, Hash

  scope :accessibles, -> (current_user) {
    if current_user.present?
      where("is_public = true or user_id = #{current_user.id}")
    else
      where(is_public: true)
    end
  }

  def changeable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end
end
