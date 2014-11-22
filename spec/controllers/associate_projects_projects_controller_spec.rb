# encoding: utf-8
require 'spec_helper'

describe AssociateProjectsProjectsController do
  describe 'destroy' do
    before do
      request.env["HTTP_REFERER"] = projects_path
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 20, :pmcdocs_count => 30, :denotations_count => 40, :relations_count => 50)
      @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0, :denotations_count => 0, :relations_count => 0)
      @associate_project_pmdocs_count = 10
      @associate_project_pmdocs_count.times do
        @associate_project.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed') 
      end
      @associate_project_pmcdocs_count = 20
      @associate_project_pmcdocs_count.times do |time|
        @associate_project.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, sourceid: time.to_s) 
      end     
      @associate_project_denotations_count = 30
      @associate_project_denotations_count.times do
        FactoryGirl.create(:denotation, :project => @associate_project, :doc_id => 1) 
      end     
      @associate_project_relations_count = 40
      @associate_project_relations_count.times do
        FactoryGirl.create(:relation, :project => @associate_project, :obj_id => 1)
      end     
      @associate_project.reload
      @associate_projects_project = FactoryGirl.create(:associate_projects_project, :project_id => @project.id, :associate_project_id => @associate_project.id)
      delete :destroy, :project_id => @project.id, :associate_project_id => @associate_project.id
    end
    
    it 'should delete record' do
      AssociateProjectsProject.where(:id => @associate_projects_project).should be_blank
    end
    
    it 'should redirect referer path' do
      response.should redirect_to(projects_path) 
    end
    
    it 'should decrement project.counters' do
      @project.reload
      @project.pmdocs_count.should eql(10)
      @project.pmcdocs_count.should eql(10)
      @project.denotations_count.should eql(10)
      @project.relations_count.should eql(10)
    end
  end
end
