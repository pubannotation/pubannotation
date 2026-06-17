# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  subject(:doc) { create(:doc, medium: medium) }

  context 'with medium' do
    let(:medium) { create(:medium) }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: medium) }
    end

    describe 'medium_id immutability' do
      it 'cannot change medium after creation' do
        other_medium = create(:medium, sourcedb: 'DB2', sourceid: 'id2')
        doc.medium = other_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end

  context 'without medium' do
    let(:medium) { nil }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: nil) }
    end

    describe 'medium_id immutability' do
      it 'cannot add medium after creation' do
        new_medium = create(:medium)
        doc.medium = new_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end
end
