require 'rails_helper'

RSpec.describe Sentence, type: :model do
  describe 'search_by_term' do
    let(:user) { create(:user) }
    let(:base_project_name) { nil }
    let(:terms) { nil }
    let(:predicates) { nil }
    let(:projects) { nil }
    let(:page) { 1 }
    let(:per) { 10 }
    subject { Sentence.search_by_term user, base_project_name, terms, predicates, projects, page, per }

    it 'returns an array' do
      expect(subject).to be_a(Array)
    end

    it 'returns an array of hashes' do
      expect(subject).to all(be_a(Hash))
    end

    context 'when there are sentences' do
      let(:doc) { create(:doc) }
      let(:project) { create(:project, name: 'Project', user: user) }

      before do
        doc.projects << project
        create(:sentence, doc: doc, begin: 0, end: 10)
        create(:sentence, doc: doc, begin: 11, end: 20)
        create(:sentence, doc: doc, begin: 21, end: 30)

        doc2 = create(:doc)
        project2 = create(:project, name: 'Project2', user: user)
        doc2.projects << project2
        create(:sentence, doc: doc2, begin: 0, end: 10)
        create(:sentence, doc: doc2, begin: 11, end: 20)
        create(:sentence, doc: doc2, begin: 21, end: 30)
      end

      it 'returns all sentences' do
        expect(subject.size).to eq(Sentence.count)
      end

      context 'when base_project_name is specified' do
        let(:base_project_name) { 'Project' }

        it 'returns sentences in doc in base_project' do
          expect(subject.size).to eq(3)
        end

        it 'return value contains url' do
          expect(subject.first[:url]).to be_present
        end

        it 'return value contains begin' do
          expect(subject.first[:begin]).to be_present
        end

        it 'return value contains end' do
          expect(subject.first[:end]).to be_present
        end
      end

      context 'when sentence has denotations' do
        before do
          sentence = Sentence.first
          denotation = create(:denotation, project: project, obj: 'test_denotation')
          sentence.denotations << denotation
        end

        let(:terms) { ['test_denotation'] }
        let(:predicates) { ['denotes'] }

        it 'returns sentences with denotations' do
          expect(subject.size).to eq(1)
        end

        context 'with projects parameter' do
          let(:projects) { ['Project2'] }

          it 'returns sentences with denotations' do
            expect(subject.size).to eq(0)
          end
        end

        context 'when sentence has attributes' do
          before do
            sentence = Sentence.first
            attrivute = create(:attrivute,
                               doc: sentence.doc,
                               project: project,
                               subj: sentence.denotations.first,
                               pred: 'test_predicate',
                               obj: 'test_attrivute')
            sentence.attrivutes << attrivute
          end

          let(:terms) { ['test_attrivute'] }
          let(:predicates) { ['test_predicate'] }

          it 'returns sentences with attributes' do
            expect(subject.size).to eq(1)
          end

          context 'without predicates parameter' do
            let(:terms) { ['test_attrivute'] }
            let(:predicates) { nil }

            it 'returns sentences with attributes' do
              expect(subject.size).to eq(1)
            end
          end
        end
      end
    end
  end
end