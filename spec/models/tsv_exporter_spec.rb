# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TsvExporter do
  it 'exports hash keys as TSV headers and quotes tabs, newlines, and quotes' do
    rows = [{ sourcedb: 'PMC', text: "a\tb\n\"c\"" }, { sourcedb: 'PubMed', text: 'plain' }]

    expect(TsvExporter.call(rows)).to eq("sourcedb\ttext\nPMC\t\"a\tb\n\"\"c\"\"\"\nPubMed\tplain\n")
  end

  it 'returns nil for an empty hash collection' do
    expect(TsvExporter.call([])).to be_nil
    expect(TsvExporter.call(nil)).to be_nil
  end
end
