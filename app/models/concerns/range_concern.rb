# frozen_string_literal: true

module RangeConcern
  extend ActiveSupport::Concern
  include ProjectMemberConcern

  included do
    scope :in_span, -> (span) do
      if span.present?
        where('begin >= ?', span[:begin])
          .where('"end" <= ?', span[:end])
      end
    end

    scope :with_term, lambda { |term|
      if term
        joins(:attrivutes).where(attrivutes: { obj: term })
                          .or(joins(:attrivutes).where(obj: term))
      end
    }

    scope :in_project_and_span, -> (project_id, span) do
      in_project(project_id).in_span(span)
    end
  end

  def <=>(other)
    (self.begin <=> other.begin).nonzero? || (self.end <=> other.end)
  end
end
