require 'rails_helper'

RSpec.describe Paragraph, type: :model do
  describe 'search_by_term' do
    let(:user) { create(:user) }
    let(:base_project_name) { nil }
    let(:terms) { nil }
    let(:predicates) { nil }
    let(:projects) { nil }
    let(:page) { 1 }
    let(:per) { 10 }
    subject { Paragraph.search_by_term user, base_project_name, terms, predicates, projects, page, per }

    it 'returns an array' do
      expect(subject).to be_a(Array)
    end

    it 'returns an array of hashes' do
      expect(subject).to all(be_a(Hash))
    end

    context 'when there are paragraphs' do
      let(:doc) { create(:doc) }
      let(:project) { create(:project, name: 'Project', user: user) }

      before do
        doc.projects << project
        create(:paragraph, doc: doc, begin: 0, end: 10)
        create(:paragraph, doc: doc, begin: 11, end: 20)
        create(:paragraph, doc: doc, begin: 21, end: 30)

        doc2 = create(:doc)
        project2 = create(:project, name: 'Project2', user: user)
        doc2.projects << project2
        create(:paragraph, doc: doc2, begin: 0, end: 10)
        create(:paragraph, doc: doc2, begin: 11, end: 20)
        create(:paragraph, doc: doc2, begin: 21, end: 30)
      end

      it 'returns all paragraphs' do
        expect(subject.size).to eq(Paragraph.count)
      end

      context 'when base_project_name is specified' do
        let(:base_project_name) { 'Project' }

        it 'returns paragraphs in doc in base_project' do
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

      context 'when paragraph has denotations' do
        before do
          paragraph = Paragraph.first
          denotation = create(:denotation, project: project, obj: 'test_denotation')
          paragraph.denotations << denotation
        end

        let(:terms) { ['test_denotation'] }
        let(:predicates) { ['denotes'] }

        it 'returns paragraphs with denotations' do
          expect(subject.size).to eq(1)
        end

        context 'with projects parameter' do
          let(:projects) { ['Project2'] }

          it 'returns paragraphs with denotations' do
            expect(subject.size).to eq(0)
          end
        end

        context 'when paragraph has attributes' do
          before do
            paragraph = Paragraph.first
            attrivute = create(:attrivute,
                               doc: paragraph.doc,
                               project: project,
                               subj: paragraph.denotations.first,
                               pred: 'test_predicate',
                               obj: 'test_attrivute')
            paragraph.attrivutes << attrivute
          end

          let(:terms) { ['test_attrivute'] }
          let(:predicates) { ['test_predicate'] }

          it 'returns paragraphs with attributes' do
            expect(subject.size).to eq(1)
          end

          context 'without predicates parameter' do
            let(:terms) { ['test_attrivute'] }
            let(:predicates) { nil }

            it 'returns paragraphs with attributes' do
              expect(subject.size).to eq(1)
            end
          end
        end
      end
    end
  end
end
