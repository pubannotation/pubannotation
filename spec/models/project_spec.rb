# encoding: utf-8
require 'spec_helper'

describe Project do
  describe 'belongs_to user' do
    before do
      @user = FactoryGirl.create(:user, :id => 5)
      @project = FactoryGirl.create(:project, :user => @user)
    end
    
    it 'project should belongs_to user' do
      @project.user.should eql(@user)
    end
  end
  
  describe 'has_and_belongs_to_many docs' do
    before do
      @doc_1 = FactoryGirl.create(:doc, :id => 3)
      @project_1 = FactoryGirl.create(:project, :id => 5, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :id => 7, :user => FactoryGirl.create(:user))
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc))
    end
    
    it 'doc.projects should include @project_1' do
      @doc_1.projects.should include(@project_1)
    end
    
    it '@project_1.docs should include @doc' do
      @project_1.docs.should include(@doc_1)
    end
    
    it 'doc.projects should include @project_2' do
      @doc_1.projects.should include(@project_2)
    end

    it '@project_2.docs should include @doc' do
      @project_2.docs.should include(@doc_1)
    end
  end
  
  describe 'has_many spans' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @span = FactoryGirl.create(:span, :project => @project, :doc => FactoryGirl.create(:doc))
    end
    
    it 'project.spans should be present' do
      @project.spans.should be_present
    end
    
    it 'project.spans should include related span' do
      (@project.spans - [@span]).should be_blank
    end
  end
  
  describe 'has_many relations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :project => @project, :relobj_id => 5)
    end
    
    it 'project.relations should be present' do
      @project.relations.should be_present
    end
    
    it 'project.relations should include related relation' do
      (@project.relations - [@relation]).should be_blank
    end
  end
  
  describe 'has_many insanns' do
    pending 'insanns will be changed'
  end
  
  describe 'has_many modifications' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @modification = FactoryGirl.create(:modification, :modobj_id => 1, :project => @project)      
    end
    
    it 'project.modifications should be present' do
      @project.modifications.should be_present
    end
    
    it 'project.modifications should include related modification' do
      (@project.modifications - [@modification]).should be_blank
    end
  end
end
