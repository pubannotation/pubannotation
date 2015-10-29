require 'spec_helper'

describe AnnotationsProject do
  describe 'delete_annotation_if_not_belongs_to' do
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :another_project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc_id: 1) }
    let( :annotations_project) { FactoryGirl.create(:annotations_project, annotation: denotation, project: project) }
    let( :annotations_another_project) { FactoryGirl.create(:annotations_project, annotation: denotation, project: another_project) }

    before do
      annotations_project.reload
      annotations_another_project.reload
      denotation.reload
    end
    
    context 'when annotation belongs to project after destroy annotations_project' do
      it 'should not delete annotation' do
        expect{ annotations_project.destroy }.not_to change{Denotation.all.count}.from(1).to(0)
      end
    end

    context 'when annotation not belongs to project after destroy annotations_project' do
      before do
        annotations_project.destroy
      end

      it 'should not delete annotation' do
        expect{ annotations_another_project.destroy }.to change{Denotation.all.count}.from(1).to(0)
      end
    end
  end
end
