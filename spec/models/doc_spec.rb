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
    subject { doc.get_denotations(project.id, span, context_size, false) }

    let(:doc) { create(:doc) }
    let(:project) { create(:project) }
    let(:span) { nil }
    let(:context_size) { nil }

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

        context 'when context_size is specified' do
          let(:context_size) { 6 }

          it 'returns an array of denotations offset by the specified span and context_size' do
            expect(subject.first.begin).to eq(object_denotation.begin - span[:begin] + context_size)
            expect(subject.first.end).to eq(object_denotation.end - span[:begin] + context_size)
          end

          context 'when context_size equals to begin of the span' do
            let(:context_size) { 8 }

            it 'returns an array of denotations without offset' do
              expect(subject.first.begin).to eq(object_denotation.begin)
              expect(subject.first.end).to eq(object_denotation.end)
            end
          end

          context 'when context_size is bigger than begin of the span' do
            let(:context_size) { 10 }

            it 'returns an array of denotations without offset' do
              expect(subject.first.begin).to eq(object_denotation.begin)
              expect(subject.first.end).to eq(object_denotation.end)
            end
          end
        end
      end
    end
  end
end
