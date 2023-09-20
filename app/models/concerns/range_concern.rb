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
  end

  def <=>(other)
    (self.begin <=> other.begin).nonzero? || (self.end <=> other.end)
  end
end
