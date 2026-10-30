# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TextStructurePresenter, type: :model do
  [[:divisions, :label, 'p'], [:typesettings, :style, 'bold']].each do |association, field, value|
    describe "#{association}" do
      let(:doc) { create(:doc, body: '0123456789abcdefghij') }
      let(:presenter) { described_class.new(doc.public_send(association), doc.body.length) }

      def add_structure(doc, association, field, value, first, last)
        doc.public_send(association).create!(field => value, begin: first, end: last)
      end

      it 'returns all structures with absolute offsets when no span is specified' do
        add_structure(doc, association, field, value, 4, 7)

        expect(presenter.to_a).to eq([{ field => value, span: { begin: 4, end: 7 } }])
      end

      it 'returns an empty array when no structures exist' do
        expect(presenter.to_a({ begin: 3, end: 10 })).to eq([])
      end

      it 'selects contained structures and returns offsets relative to the requested span' do
        add_structure(doc, association, field, value, 1, 5)
        add_structure(doc, association, field, value, 4, 7)
        add_structure(doc, association, field, value, 8, 12)

        expect(presenter.to_a({ begin: 3, end: 10 })).to eq([
          { field => value, span: { begin: 1, end: 4 } }
        ])
      end

      it 'keeps stored offsets unchanged across repeated exports and later saves' do
        add_structure(doc, association, field, value, 4, 7)
        doc.reload
        doc.public_send(association).load
        structure = doc.public_send(association).first
        expected = [{ field => value, span: { begin: 1, end: 4 } }]

        expect(presenter.to_a({ begin: 3, end: 10 })).to eq(expected)
        expect(presenter.to_a({ begin: 3, end: 10 })).to eq(expected)
        expect(presenter.to_a).to eq([{ field => value, span: { begin: 4, end: 7 } }])
        expect([structure.begin, structure.end]).to eq([4, 7])
        expect(structure).not_to be_changed

        structure.save!
        expect([structure.reload.begin, structure.end]).to eq([4, 7])
      end

      it 'includes structures in the context and measures offsets from the context start' do
        add_structure(doc, association, field, value, 3, 6)

        expect(presenter.to_a({ begin: 5, end: 10 }, 3)).to eq([
          { field => value, span: { begin: 1, end: 4 } }
        ])
      end

      it 'clips context to the body boundaries' do
        add_structure(doc, association, field, value, 0, 3)
        add_structure(doc, association, field, value, 15, 18)

        expect(presenter.to_a({ begin: 2, end: 18 }, 5)).to eq([
          { field => value, span: { begin: 0, end: 3 } },
          { field => value, span: { begin: 15, end: 18 } }
        ])
      end

    end
  end

end
