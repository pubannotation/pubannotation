require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'hannotations' do
    let(:doc) { create(:doc) }
    subject { doc.hannotations nil, nil , nil, {} }

    it 'returns a hash' do
      expect(subject).to be_a(Hash)
    end

    it 'has the expected target' do
      expect(subject[:target]).to eq("http://test.pubannotation.org/docs/sourcedb/PubMed/sourceid/#{doc.sourceid}")
    end

    it 'has the expected sourcedb' do
      expect(subject[:sourcedb]).to eq('PubMed')
    end

    it 'has the expected sourceid' do
      expect(subject[:sourceid]).to eq(doc.sourceid)
    end

    it 'has the expected text' do
      expect(subject[:text]).to eq("This is a test.\nTest are implemented.\nImplementation is difficult.")
    end

    it 'has empty tracks' do
      expect(subject[:tracks]).to eq([])
    end

    context 'when document has denotations' do
      let(:project) { create(:project, accessibility: 1) }
      let!(:denotation) { create(:denotation, doc: doc, project: project) }
      let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

      before do
        # Add project_doc after denotation is created
        doc.reload
      end

      it 'includes denotations in tracks' do
        expect(subject[:tracks]).to include(project: "TestProject",
                                            denotations: [{
                                                            id: "T1",
                                                            obj: "subject",
                                                            span: {begin: 0, end: 4}
                                                          }]
                                    )
      end

      context 'when specified project is single' do
        let(:project) { create(:project) }

        it 'returns denotations but no tracks' do
          annotations = doc.hannotations(project, nil, nil, {})
          expect(annotations[:tracks]).to be_nil
          expect(annotations[:denotations]).to include(id: "T1",
                                                       obj: "subject",
                                                       span: {begin: 0, end: 4}
                                               )
        end
      end

      context 'when document has multiple projects' do
        let(:project2) { create(:project, name: 'AnotherProject') }
        let!(:project_doc2) { create(:project_doc, project: project2, doc: doc) }

        it 'has a single track with denotations' do
          expect(subject[:tracks].size).to eq(1)
        end

        context 'when full option is specified' do
          it 'includes all tracks regardless of denotations' do
            full_annotations = doc.hannotations(nil, nil, nil, {full: true})
            expect(full_annotations[:tracks].size).to eq(2)
          end
        end
      end
    end
  end
end
