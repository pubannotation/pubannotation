class Collection < ActiveRecord::Base
  belongs_to :user
  attr_accessible :description, :name, :reference,
  								:is_sharedtask, :accessibility
  has_many :collection_projects, dependent: :destroy
  has_many :projects, through: :collection_projects

  scope :accessible, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        where('collections.accessibility = ? OR collections.user_id =?', 1, current_user.id)
      end
    else
      where(accessibility: [1, 3])
    end
  }

  scope :editable, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        where('collections.user_id =?', current_user.id)
      end
    end
  }

  scope :sharedtasks, where(is_sharedtask: true)
  scope :no_sharedtasks, where(is_sharedtask: false)

  scope :top_recent, order('collections.updated_at DESC').limit(10)

  def editable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end

  def destroyable?(current_user)
    current_user.present? && (current_user.root? || current_user == user)
  end

end
