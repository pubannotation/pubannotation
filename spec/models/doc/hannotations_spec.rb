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
      expect(doc.hannotations[:text]).to eq("This is a test.\nTest are implemented.\nImplementation is difficult.")
    end

    it 'returns a hash with tracks' do
      expect(doc.hannotations[:tracks]).to eq([])
    end

    context 'when document has denotations' do
      let(:project) { create(:project, accessibility: 1) }
      let!(:denotation) { create(:denotation, doc: doc, project: project) }
      let!(:project_doc) { create(:project_doc, project: project, doc: doc) }

      # Add project_doc after denotation is created
      before { doc.reload }

      it 'returns a hash with tracks that includes denotations' do
        expect(doc.hannotations[:tracks]).to include(project: "TestProject",
                                                            denotations: [{
                                                                            id: "T1",
                                                                            obj: "subject",
                                                                            span: {begin: 0, end: 4}
                                                                          }]
                                             )
      end

      context 'when specified project is single' do
        let(:project) { create(:project) }

        it 'returns a hash without tracks' do
          expect(doc.hannotations(project)[:tracks]).to be_nil
        end

        it 'returns a hash with denotations' do
          expect(doc.hannotations(project)[:denotations]).to include(id: "T1",
                                                                      obj: "subject",
                                                                      span: {begin: 0, end: 4}
                                                                    )
        end
      end

      context 'when document has multiple projects' do
        let(:project2) { create(:project, name: 'AnotherProject') }
        let!(:project_doc2) { create(:project_doc, project: project2, doc: doc) }

        it 'returns a hash with tracks that has denotations' do
          expect(doc.hannotations[:tracks].size).to eq(1)
        end

        context 'when full option is specified' do
          it 'returns a hash with tracks that has denotations or not' do
            expect(doc.hannotations(nil, nil, nil, {full: true})[:tracks].size).to eq(2)
          end
        end
      end
    end
  end
end
