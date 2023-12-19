require 'rails_helper'

RSpec.describe Denotation, type: :model do
  describe 'in_project' do
    it 'should return denotations in project' do
      project = create(:project)
      denotation = create(:denotation, project: project)

      expect(Denotation.in_project(project.id)).to include(denotation)
    end

    it 'should not return denotations not in project' do
      project = create(:project)

      another_project = create(:another_project)
      denotation = create(:denotation, project: another_project)

      expect(Denotation.in_project(project.id)).not_to include(denotation)
    end

    context 'when project_id is nil' do
      it 'should return all denotations' do
        project = create(:project)
        denotation = create(:denotation, project: project)

        another_project = create(:another_project)
        another_denotation = create(:denotation, project: another_project)

        result = Denotation.in_project(nil)
        expect(result).to include(denotation)
        expect(result).to include(another_denotation)
      end
    end
  end

  describe 'in_span' do
    let(:denotation) { create(:denotation) }

    it 'should return denotations in span' do
      expect(Denotation.in_span({begin: 0, end: 4})).to include(denotation)
    end

    it 'should not return denotations outside of span begin' do
      expect(Denotation.in_span(begin: 1, end: 4)).not_to include(denotation)
    end

    it 'should not return denotations outside of span end' do
      expect(Denotation.in_span(begin: 0, end: 3)).not_to include(denotation)
    end

    context 'when span is nil' do
      it 'should return all denotations' do
        expect(Denotation.in_span(nil)).to include(denotation)
      end
    end
  end
end
