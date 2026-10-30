# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'import filename', type: :model do
  it 'parses filenames using the final hyphen as the source ID separator' do
    expect(Doc.parse_filename('my-source-123')).to eq(['my-source', '123'])
    expect { Doc.parse_filename('invalid') }.to raise_error(ArgumentError, /sourcedb-sourceid/)
  end
end
