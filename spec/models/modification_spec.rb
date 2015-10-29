require 'spec_helper'

describe Relation do
  describe 'belongs_to obj' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      Modification.any_instance.stub(:increment_project_annotations_count).and_return(nil)
      @modification = FactoryGirl.create(:modification, :obj => @instance)
      FactoryGirl.create(:annotations_project, project: @project , annotation: @modification )
    end
    
    it 'modification should belongs to obj' do
      @modification.obj.should eql(@instance)
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      FactoryGirl.create(:annotations_project, project: @project , annotation: @denotation)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :subj => @denotation)
      FactoryGirl.create(:annotations_project, project: @project , annotation: @subcatrel)
      Modification.any_instance.stub(:increment_project_annotations_count).and_return(nil)
      @insmod = FactoryGirl.create(:modification, 
        :hid => 'modification hid',
        :pred => 'pred',
        :obj => @instance 
      )
      FactoryGirl.create(:annotations_project, project: @project , annotation: @insmod)
      @get_hash = @insmod.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@insmod[:hid])
    end
    
    it 'should set pred as type' do
      @get_hash[:pred].should eql(@insmod[:pred])
    end
    
    it 'should set end as denotation:end' do
      @get_hash[:obj].should eql(@instance[:hid])
    end
  end

  describe 'increment_project_annotations_count' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      FactoryGirl.create(:annotations_project, project: @project , annotation: @denotation)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @modification = FactoryGirl.create(:modification, 
        :hid => 'modification hid',
        :pred => 'pred',
        :obj => @instance 
      )
      FactoryGirl.create(:annotations_project, project: @project , annotation: @insmod)
      @project.reload
    end

    it 'should increment project.annotations_count' do
      expect{  
        @modification.increment_project_annotations_count
        @project.reload
      }.to change{ @project.annotations_count }.from(2).to(3)
    end
  end

  describe 'decrement_project_annotations_count' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @modification = FactoryGirl.create(:modification, 
        :hid => 'modification hid',
        :pred => 'pred',
        :obj => @instance, 
        :project => @project
      )
      @project.reload
    end

    it 'should decrement project.annotations_count' do
      expect{  
        @modification.decrement_project_annotations_count
        @project.reload
      }.to change{ @project.annotations_count }.from(2).to(1)
    end
  end
end
