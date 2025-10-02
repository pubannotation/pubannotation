# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'factory' do
    it 'creates a valid doc' do
      doc = create(:doc)
      expect(doc).to be_persisted
      expect(doc.sourcedb).to be_present
      expect(doc.sourceid).to be_present
      expect(doc.body).to be_present
    end
  end

  describe 'validations' do
    it 'requires sourcedb and sourceid' do
      doc = Doc.new
      expect(doc).not_to be_valid
    end
  end
end
