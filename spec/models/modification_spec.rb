require 'spec_helper'

describe Relation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @modification = FactoryGirl.create(:modification, :obj => @denotation, :project => @project)
    end
    
    it 'modification should belongs to project' do
      @modification.project.should eql(@project)
    end
  end

  describe 'belongs_to obj' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @modification = FactoryGirl.create(:modification, :obj => @instance, :project => @project)
    end
    
    it 'modification should belongs to obj' do
      @modification.obj.should eql(@instance)
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :project => @project)
      @insmod = FactoryGirl.create(:modification, 
        :hid => 'modification hid',
        :pred => 'pred',
        :obj => @instance, 
        :project => @project
      )
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
end
