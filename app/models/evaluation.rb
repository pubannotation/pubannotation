class Evaluation < ActiveRecord::Base
  belongs_to :study_project, class_name: 'Project'
  belongs_to :reference_project, class_name: 'Project'
  belongs_to :evaluator
  attr_accessible :result, :is_public, :study_project, :reference_project, :evaluator, :note, :user_id,
                  :soft_match_characters, :soft_match_words, :denotations_type_match, :relations_type_match

  validates :user_id, presence: true
  validates :study_project, presence: true
  validates :reference_project, presence: true
  validates :evaluator, presence: true
  validates_each :reference_project do |record, attr, value|
    unless value.nil?
      if value == record.study_project
        record.errors.add(attr, "must be a different one from the study_project.")
      else
        docs_std = record.study_project.docs
        docs_ref = value.docs
        docs_common = docs_std & docs_ref
        record.errors.add(attr, "has no shared document with the study project.") if docs_common.length == 0
        record.errors.add(attr, "has too many (> 5,000) shared document with the study project.") if docs_common.length > 5000
      end
    end
  end

  scope :accessible, -> (current_user) {
    if current_user.present?
      if current_user.root?
      else
        where('is_public = ? OR user_id =?', true, current_user.id)
      end
    else
      where(is_public: true)
    end
  }

  def changeable?(current_user)
    current_user.present? && (current_user.root? || current_user == study_project.user)
  end
end
