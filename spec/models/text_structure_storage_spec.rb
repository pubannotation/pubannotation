# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Text structure storage', type: :model do
  [
    [Division, :divisions, :label, 'p', 'Failed to save the divisions.'],
    [Typesetting, :typesettings, :style, 'bold', 'Failed to save the typesettings.']
  ].each do |model, association, field, value, error|
    describe model do
      let(:doc) { create(:doc, body: '0123456789') }

      it 'returns an empty array for nil input without importing' do
        expect(model).not_to receive(:import)
        expect(model.store_for(doc, nil)).to eq([])
      end

      it 'imports multiple structures for the given document and returns them' do
        items = [
          { field => value, span: { begin: 0, end: 3 } },
          { field => value, span: { begin: 4, end: 7 } }
        ]

        result = model.store_for(doc, items)

        expect(result.map(&:to_hash)).to eq(items)
        expect(doc.public_send(association).reload.map(&:to_hash)).to match_array(items)
      end

      it 'raises if the import reports failed records' do
        allow(model).to receive(:import).and_return(double(failed_instances: [model.new]))

        expect { model.store_for(doc, [{ field => value, span: { begin: 0, end: 3 } }]) }.to raise_error(error)
      end
    end
  end
end
