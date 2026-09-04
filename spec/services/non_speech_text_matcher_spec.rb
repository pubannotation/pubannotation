# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NonSpeechTextMatcher do
  describe '.match?' do
    it 'matches a known label in parentheses' do
      expect(described_class.match?('(upbeat music)')).to be true
    end

    it 'matches a known label in square brackets' do
      expect(described_class.match?('[applause]')).to be true
    end

    it 'matches case-insensitively' do
      expect(described_class.match?('(Applause)')).to be true
    end

    it 'matches a bare musical note' do
      expect(described_class.match?('♪')).to be true
    end

    it 'does not match ordinary spoken text' do
      expect(described_class.match?('Welcome to the conference.')).to be false
    end

    it 'does not match spoken text that happens to contain parentheses' do
      expect(described_class.match?('the meeting (which ran long) covered budget')).to be false
    end

    it 'does not match a bracketed label outside the known list' do
      expect(described_class.match?('(footsteps approaching)')).to be false
    end

    it 'does not match blank text' do
      expect(described_class.match?('')).to be false
      expect(described_class.match?(nil)).to be false
    end
  end
end
