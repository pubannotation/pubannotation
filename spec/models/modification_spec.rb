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
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @modification = FactoryGirl.create(:modification, :obj => @instance, :project => @project)
    end
    
    it 'modification should belongs to obj' do
      @modification.obj.should eql(@instance)
    end
  end

  describe 'after_save' do
    let( :updated_at ) { 10.days.ago }
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), updated_at: updated_at) }
    let( :doc ) { FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body') }
    let( :denotation ) { FactoryGirl.create(:denotation, :project => project, :doc => doc) }
    let( :instance ) { FactoryGirl.create(:instance, :hid => 'instance hid', :project => project, :obj => denotation) }
    let( :modification ) { FactoryGirl.create(:modification, :hid => 'modification hid', :pred => 'pred', :obj => instance, :project => project) }

    it 'should call increment_project_annotations_count' do
      expect( modification ).to receive(:increment_project_annotations_count)
      modification.save
    end

    it 'should call update_project_updated_at' do
      expect( modification ).to receive(:update_project_updated_at)
      modification.save
    end
  end

  describe 'after_destroy' do
    let( :updated_at ) { 10.days.ago }
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), updated_at: updated_at) }
    let( :doc ) { FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body') }
    let( :denotation ) { FactoryGirl.create(:denotation, :project => project, :doc => doc) }
    let( :instance ) { FactoryGirl.create(:instance, :hid => 'instance hid', :project => project, :obj => denotation) }
    let( :modification ) { FactoryGirl.create(:modification, :hid => 'modification hid', :pred => 'pred', :obj => instance, :project => project) }

    it 'should call increment_project_annotations_count' do
      expect( modification ).to receive(:decrement_project_annotations_count)
      modification.destroy
    end

    it 'should call update_project_updated_at' do
      expect( modification ).to receive(:update_project_updated_at)
      modification.destroy
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :hid => 'instance hid', :project => @project, :obj => @denotation)
      @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :subj => @denotation, :project => @project)
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

  describe 'increment_project_annotations_count' do
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

    it 'should increment project.annotations_count' do
      expect{  
        @modification.increment_project_annotations_count
        @project.reload
      }.to change{ @project.annotations_count }.from(2).to(3)
    end
  end

  describe 'update_project_updated_at' do
    let( :updated_at ) { 10.days.ago }
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), updated_at: updated_at) }
    let( :doc ) { FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body') }
    let( :denotation ) { FactoryGirl.create(:denotation, :project => project, :doc => doc) }
    let( :instance ) { FactoryGirl.create(:instance, :hid => 'instance hid', :project => project, :obj => denotation) }
    let( :modification ) { FactoryGirl.create(:modification, :hid => 'modification hid', :pred => 'pred', :obj => instance, :project => project) }

    it 'should update project.updated_at' do
      modification.update_project_updated_at
      expect( project.updated_at ).not_to eql(updated_at)
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
