# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, 'text structure', type: :model do
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
