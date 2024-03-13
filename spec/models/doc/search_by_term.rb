require 'rails_helper'

RSpec.describe Doc, type: :model do
  describe 'search_by_term' do
    let(:user) { create(:user) }
    let(:base_project_name) { nil }
    let(:terms) { nil }
    let(:predicates) { nil }
    let(:projects) { nil }
    let(:page) { 1 }
    let(:per) { 10 }
    subject { Doc.search_by_term user, base_project_name, terms, predicates, projects, page, per }

    it 'returns an array' do
      expect(subject).to be_a(Array)
    end

    it 'returns an array of hashes' do
      expect(subject).to all(be_a(Hash))
    end

    context 'when there are docs' do
      let(:doc) { create(:doc) }
      let(:project) { create(:project, name: 'Project', user: user) }

      before do
        doc.projects << project

        doc2 = create(:doc)
        project2 = create(:project, name: 'Project2', user: user)
        doc2.projects << project2
      end

      it 'returns all docs' do
        expect(subject.size).to eq(Doc.count)
      end

      context 'when base_project_name is specified' do
        let(:base_project_name) { 'Project' }

        it 'returns docs in doc in base_project' do
          expect(subject.size).to eq(1)
        end

        it 'return value contains url' do
          expect(subject.first[:url]).to be_present
        end

        it 'return value contains begin' do
          expect(subject.first[:sourcedb]).to be_present
        end

        it 'return value contains end' do
          expect(subject.first[:sourceid]).to be_present
        end
      end

      context 'when doc has denotations' do
        before do
          denotation = create(:denotation, project: project, obj: 'test_denotation')
          doc.denotations << denotation
        end

        let(:terms) { ['test_denotation'] }
        let(:predicates) { ['denotes'] }

        it 'returns docs with denotations' do
          expect(subject.size).to eq(1)
        end

        context 'with projects parameter' do
          let(:projects) { ['Project2'] }

          it 'returns docs with denotations' do
            expect(subject.size).to eq(0)
          end
        end

        context 'when doc has attributes' do
          before do
            attrivute = create(:attrivute,
                               doc: doc,
                               project: project,
                               subj: doc.denotations.first,
                               pred: 'test_predicate',
                               obj: 'test_attrivute')
            doc.attrivutes << attrivute
          end

          let(:terms) { ['test_attrivute'] }
          let(:predicates) { ['test_predicate'] }

          it 'returns docs with attributes' do
            expect(subject.size).to eq(1)
          end

          context 'without predicates parameter' do
            let(:terms) { ['test_attrivute'] }
            let(:predicates) { nil }

            it 'returns docs with attributes' do
              expect(subject.size).to eq(1)
            end
          end
        end
      end
    end
  end
end
