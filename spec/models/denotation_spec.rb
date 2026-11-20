# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Denotation, type: :model do
  describe '#label' do
    it 'shows the project and obj to anyone for a public project' do
      denotation = create(:denotation, project: create(:project, accessibility: 1), obj: 'Gene')

      expect(denotation.label(nil)).to eq("#{denotation.project.name}: Gene")
    end

    it 'shows only that it is there for a private project but to its owner' do
      project = create(:project, accessibility: 2)
      denotation = create(:denotation, project:, obj: 'Protein')

      expect(denotation.label(create(:user))).to eq('(private project)')
      expect(denotation.label(nil)).to eq('(private project)')
      expect(denotation.label(project.user)).to eq("#{project.name}: Protein")
    end

    it "shows only that it is there for a blind project but to its owner, the project being accessible but not its annotations" do
      project = create(:project, accessibility: 3)
      denotation = create(:denotation, project:, obj: 'Protein')

      expect(denotation.label(create(:user))).to eq('(private project)')
      expect(denotation.label(nil)).to eq('(private project)')
      expect(denotation.label(project.user)).to eq("#{project.name}: Protein")
    end
  end
end
