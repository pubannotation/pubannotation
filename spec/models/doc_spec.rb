require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'hannotations' do
    let(:doc) { create(:doc) }

    it 'returns a hash' do
      expect(doc.hannotations).to be_a(Hash)
    end

    it 'returns a hash with target' do
      expect(doc.hannotations[:target]).to eq("http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}")
    end

    it 'returns a hash with sourcedb' do doc = create(:doc)
      expect(doc.hannotations[:sourcedb]).to eq('PubMed')
    end

    it 'returns a hash with sourceid' do
      expect(doc.hannotations[:sourceid]).to eq(doc.sourceid)
    end

    it 'returns a hash with text' do
      expect(doc.hannotations[:text]).to eq('This is a test.')
    end

    it 'returns a hash with tracks' do
      expect(doc.hannotations[:tracks]).to eq([])
    end

    context 'when specified project is single' do
      let(:project) { create(:project) }

      it 'returns a hash without tracks' do
        expect(doc.hannotations(project)[:tracks]).to be_nil
      end
    end

    context 'when document has denotations' do
      let(:project) { create(:project) }
      let!(:denotation) { create(:denotation, doc: doc, project: project) }
      let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

      it 'returns a hash with tracks that includes denotations' do
        expect(doc.hannotations[:tracks]).to include(project: "TestProject",
                                                            denotations: [{
                                                                            id: "T1",
                                                                            obj: "subject",
                                                                            span: {begin: 0, end: 4}
                                                                          }]
                                             )
      end
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
    subject { doc.get_denotations(project.id, span, nil, false) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:span) { nil }

    it 'returns an array' do
      is_expected.to be_a(ActiveRecord::AssociationRelation)
    end

    context 'when there are no denotations' do
      it { is_expected.to be_empty }
    end

    context 'when there are denotations' do
      before do
        create(:denotation, doc: doc, project: project)
      end

      it { is_expected.not_to be_empty }

      it 'returns an array of denotations' do
        expect(subject.first).to be_a(Denotation)
      end

      context 'when span is specified' do
        let(:span) { {begin: 8, end: 14} }
        let!(:object_denotation) { create(:object_denotation, doc: doc, project: project) }

        it 'returns an array of denotations between the specified span' do
          expect(subject.first.hid).to eq(object_denotation.hid)
        end

        it 'returns an array of denotations offset by the specified span' do
          expect(subject.first.begin).to eq(object_denotation.begin - span[:begin])
          expect(subject.first.end).to eq(object_denotation.end - span[:begin])
        end
      end
    end
  end
end
