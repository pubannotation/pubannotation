# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchResults, type: :model do
  let(:response) { { 'hits' => { 'hits' => [], 'total' => { 'value' => 95, 'relation' => 'eq' } } } }

  it 'exposes the page and page size supplied at construction' do
    results = described_class.new(response, Doc, page: 3, per: 10)

    expect(results).to have_attributes(page: 3, per: 10, current_page: 3, limit_value: 10, per_page: 10)
  end

  it 'rounds up the page count and calculates the offset for a middle page' do
    results = described_class.new(response, Doc, page: 3, per: 10)

    expect(results).to have_attributes(total_pages: 10, num_pages: 10, offset: 20)
    expect(results).not_to be_first_page
    expect(results).not_to be_last_page
    expect(results).not_to be_out_of_range
  end

  it 'recognizes the first page with the default pagination' do
    results = described_class.new(response, Doc)

    expect(results).to have_attributes(current_page: 1, limit_value: 10, offset: 0)
    expect(results).to be_first_page
    expect(results).not_to be_last_page
    expect(results).not_to be_out_of_range
  end

  it 'recognizes the last page without treating it as out of range' do
    results = described_class.new(response, Doc, page: 10, per: 10)

    expect(results).to be_last_page
    expect(results).not_to be_out_of_range
    expect(results.offset).to eq(90)
  end

  it 'recognizes a page beyond the last page' do
    results = described_class.new(response, Doc, page: 11, per: 10)

    expect(results).to be_out_of_range
    expect(results.offset).to eq(100)
  end

  it 'calculates pages using the specified page size' do
    results = described_class.new(response, Doc, page: 2, per: 20)

    expect(results).to have_attributes(total_pages: 5, offset: 20, limit_value: 20)
  end
end
