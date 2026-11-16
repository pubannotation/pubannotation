# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentSourcedb do
  describe '.validate_required!' do
    it 'requires a source database when personalization is disabled' do
      [nil, '', '   '].each do |sourcedb|
        expect { described_class.validate_required!(sourcedb, true) }.to raise_error(ArgumentError, /cannot be automatically generated/)
      end
      expect { described_class.validate_required!('PMC', true) }.not_to raise_error
    end

    it 'allows a missing source database when personalization is enabled' do
      expect { described_class.validate_required!(nil, false) }.not_to raise_error
    end
  end
end
