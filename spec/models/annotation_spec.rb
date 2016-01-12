require 'spec_helper'

describe Annotation do
  describe 'from_projects' do
    let( :annotation_1 ) { FactoryGirl.create(:annotation, doc_id: 1) }
    let( :annotation_2 ) { FactoryGirl.create(:annotation, doc_id: 1) }
    let( :project_1 ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :project_2 ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :annotations_project_1) { FactoryGirl.create(:annotations_project, annotation: annotation_1, project: project_1) }
    let( :annotations_project_2) { FactoryGirl.create(:annotations_project, annotation: annotation_1, project: project_2) }
    let( :annotations_project_3) { FactoryGirl.create(:annotations_project, annotation: annotation_2, project: project_2) }

    before do
      annotations_project_1.reload
      annotations_project_2.reload
      annotations_project_3.reload
    end

    it 'should include annotation belongs_to project' do
      expect( Annotation.from_projects([project_1, project_2]) ).to include(annotation_1)
    end

    it 'should include annotation belongs_to project' do
      expect( Annotation.from_projects([project_1, project_2]) ).to include(annotation_2)
    end
  end
end
