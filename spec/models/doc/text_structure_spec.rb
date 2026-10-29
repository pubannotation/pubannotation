# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'text structure', type: :model do
  [[:divisions, :get_divisions, :label, 'p'], [:typesettings, :get_typesettings, :style, 'bold']].each do |association, method, field, value|
    describe "##{method}" do
      let(:doc) { create(:doc, body: '0123456789abcdefghij') }

      def add_structure(doc, association, field, value, first, last)
        doc.public_send(association).create!(field => value, begin: first, end: last)
      end

      it 'returns all structures with absolute offsets when no span is specified' do
        add_structure(doc, association, field, value, 4, 7)

        expect(doc.public_send(method)).to eq([{ field => value, span: { begin: 4, end: 7 } }])
      end

      it 'returns an empty array when no structures exist' do
        expect(doc.public_send(method, { begin: 3, end: 10 })).to eq([])
      end

      it 'selects contained structures and returns offsets relative to the requested span' do
        add_structure(doc, association, field, value, 1, 5)
        add_structure(doc, association, field, value, 4, 7)
        add_structure(doc, association, field, value, 8, 12)

        expect(doc.public_send(method, { begin: 3, end: 10 })).to eq([
          { field => value, span: { begin: 1, end: 4 } }
        ])
      end

      it 'includes structures in the context and measures offsets from the context start' do
        add_structure(doc, association, field, value, 3, 6)

        expect(doc.public_send(method, { begin: 5, end: 10 }, 3)).to eq([
          { field => value, span: { begin: 1, end: 4 } }
        ])
      end

      it 'clips context to the body boundaries' do
        add_structure(doc, association, field, value, 0, 3)
        add_structure(doc, association, field, value, 15, 18)

        expect(doc.public_send(method, { begin: 2, end: 18 }, 5)).to eq([
          { field => value, span: { begin: 0, end: 3 } },
          { field => value, span: { begin: 15, end: 18 } }
        ])
      end

    end
  end

  [:paragraphs, :sentences].each do |association|
    describe "#update_all_references_in_#{association}" do
      it 'refreshes references for every structure using only the document denotations' do
        doc = create(:doc, body: '0123456789abcdefghij')
        project = create(:project)
        denotation = create(:denotation, doc: doc, project: project, begin: 2, end: 4)
        create(:denotation, project: project, begin: 2, end: 4)
        structures = doc.public_send(association)
        attributes = association == :paragraphs ? { label: 'p' } : { project_id: project.id, obj: 'Sentence' }
        first = structures.create!(attributes.merge(begin: 0, end: 10))
        second = structures.create!(attributes.merge(begin: 10, end: 20))
        method = "update_all_references_in_#{association}"

        2.times { doc.public_send(method) }

        expect(first.denotations).to eq([denotation])
        expect(second.denotations).to be_empty

        denotation.update!(begin: 12, end: 14)
        doc.reload
        doc.public_send(method)

        expect(first.denotations.reload).to be_empty
        expect(second.denotations.reload).to eq([denotation])
      end
    end
  end
end
