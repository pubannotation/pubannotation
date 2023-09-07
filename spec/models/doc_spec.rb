require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'hannotations' do
    let(:doc) { create(:doc) }

    it 'returns a hash' do
      expect(doc.hannotations).to be_a(Hash)
    end

    it 'returns a hash with target' do
      expect(doc.hannotations[:target]).to eq('http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/12345678')
    end

    it 'returns a hash with sourcedb' do doc = create(:doc)
      expect(doc.hannotations[:sourcedb]).to eq('PubMed')
    end

    it 'returns a hash with sourceid' do
      expect(doc.hannotations[:sourceid]).to eq('12345678')
    end

    it 'returns a hash with text' do
      expect(doc.hannotations[:text]).to eq('This is a test.')
    end

    it 'returns a hash with tracks' do
      expect(doc.hannotations[:tracks]).to eq([])
    end
  end

  describe 'get_project_annotations' do
    let(:doc) { create(:doc) }
    let(:project) { create(:project) }

    it 'returns an array' do
      expect(doc.get_project_annotations(project)).to be_a(Hash)
    end

    it 'returns an array with project' do
      expect(doc.get_project_annotations(project)[:project]).to eq('TestProject')
    end
  end

  describe 'get_denotations' do
    let(:doc) { create(:doc) }
    let(:project) { create(:project) }

    it 'returns an array' do
      expect(doc.get_denotations(project)).to be_a(ActiveRecord::AssociationRelation)
    end

    context 'when there are no denotations' do
      it 'returns an array with denotations' do
        expect(doc.get_denotations(project)).to be_empty
      end
    end
  end
end
