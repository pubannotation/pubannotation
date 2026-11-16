# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentSourcedb do
  describe '.validate_presence_if_not_personalized!' do
    it 'requires a source database when personalization is disabled' do
      [nil, '', '   '].each do |sourcedb|
        expect { described_class.validate_presence_if_not_personalized!(sourcedb, true) }.to raise_error(ArgumentError, /cannot be automatically generated/)
      end
      expect { described_class.validate_presence_if_not_personalized!('PMC', true) }.not_to raise_error
    end

    it 'allows a missing source database when personalization is enabled' do
      expect { described_class.validate_presence_if_not_personalized!(nil, false) }.not_to raise_error
    end
  end
end
