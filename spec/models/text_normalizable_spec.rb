# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TextNormalizable do
  describe '.normalize_inline_text' do
    it 'puts line breaks and tabs as spaces' do
      expect(described_class.normalize_inline_text("Hello\r\nthere\nmy\rdear\tworld")).to eq('Hello there my dear world')
    end

    it 'puts runs of spaces as one space' do
      expect(described_class.normalize_inline_text("Hello  \t world")).to eq('Hello world')
    end

    it 'strips the text' do
      expect(described_class.normalize_inline_text(" \nHello world\n ")).to eq('Hello world')
    end

    it 'leaves nil as nil' do
      expect(described_class.normalize_inline_text(nil)).to be_nil
    end
  end
end
