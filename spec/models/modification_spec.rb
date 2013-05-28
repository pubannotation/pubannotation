require 'spec_helper'

describe Relation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @modification = FactoryGirl.create(:modification, :obj_id => 1, :project => @project)
    end
    
    it 'modification should belongs to project' do
      @modification.project.should eql(@project)
    end
  end

  describe 'belongs_to modobj' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @span)
      @modification = FactoryGirl.create(:modification, :obj => @instance, :project => @project)
    end
    
    it 'modification should belongs to modobj' do
      @modification.obj.should eql(@instance)
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @span)
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @span, :project => @project)
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
      @get_hash[:type].should eql(@insmod[:pred])
    end
    
    it 'should set end as span:end' do
      @get_hash[:object].should eql(@instance[:hid])
    end
  end
end