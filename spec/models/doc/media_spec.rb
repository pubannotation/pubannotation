# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  let(:doc) { create(:doc, medium: medium) }

  describe 'medium association' do
    context 'with medium' do
      let(:medium) { create(:medium) }

      it 'returns the associated Medium via belongs_to' do
        expect(doc.medium).to eq(medium)
      end
    end

    context 'without medium' do
      let(:medium) { nil }

      it 'medium is nil' do
        expect(doc.medium).to be_nil
      end
    end
  end

  describe 'medium_id immutability' do
    context 'with medium' do
      let(:medium) { create(:medium, sourcedb: 'DB1', sourceid: 'id1') }

      it 'cannot change medium after creation' do
        other_medium = create(:medium, sourcedb: 'DB2', sourceid: 'id2')
        doc.medium = other_medium
        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end
end
