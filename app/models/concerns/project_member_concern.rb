# frozen_string_literal: true

module ProjectMemberConcern
  extend ActiveSupport::Concern

  included do
    scope :in_project, -> (project_id) do
      if project_id.present?
        where(project_id: project_id)
      end
    end
  end
end
