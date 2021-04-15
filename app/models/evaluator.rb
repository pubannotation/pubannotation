class Evaluator < ActiveRecord::Base
	extend FriendlyId
	friendly_id :name, use: :finders

	belongs_to :user

	validates :name, :presence => true, :length => {:minimum => 5, :maximum => 32}, uniqueness: true
	validates_format_of :name, :with => /\A[a-z0-9][a-z0-9\-_]*[a-z0-9]\z/i

	validates :url, :presence => true

	scope :accessibles, -> (current_user) {
		if current_user.present?
			if current_user.root?
			else
				where("is_public = true or user_id = #{current_user.id}")
			end
		else
			where(is_public: true)
		end
	}

	def changeable?(current_user)
		current_user.present? && (current_user.root? || current_user == user)
	end
end
