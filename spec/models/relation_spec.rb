require 'spec_helper'

describe Relation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :relobj_id => 10, :project => @project)
    end
    
    it 'relation belongs to project' do
      @relation.project.should eql(@project)
    end
  end
  
  describe 'belongs_to relsub polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @relobj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
    end
    
    context 'Span' do
      before do
        @relsub = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :relsub_id => @relsub.id, :relsub_type => @relsub.class.to_s, :relobj => @relobj, :project => @project)
      end
      
      it 'relation.relsub should equal Span' do
        @relation.relsub.should eql(@relsub)
      end
    end

    context 'Insaan' do
      before do
        @relsub = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :relsub_id => @relsub.id, :relsub_type => @relsub.class.to_s, :relobj => @relobj, :project => @project)
      end
      
      it 'relation.relsub should equal Instance' do
        @relation.relsub.should eql(@relsub)
      end
    end
  end
  
  describe 'belongs_to relobj polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @relsub = FactoryGirl.create(:span, :project => @project, :doc => @doc)
    end
    
    context 'Span' do
      before do
        @relobj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :relsub => @relsub, :relobj => @relobj, :relobj_type => @relobj.class.to_s, :project => @project)
      end
      
      it 'relation.relobj should equal Span' do
        @relation.relobj.should eql(@relobj)
      end
    end

    context 'Insaan' do
      before do
        @relobj = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :relsub => @relsub, :relobj => @relobj, :relobj_type => @relobj.class.to_s, :project => @project)
      end
      
      it 'relation.relsub should equal Instance' do
        @relation.relobj.should eql(@relobj)
      end
    end
  end
  
  describe 'has_many modifications' do
    before do
      @relation = FactoryGirl.create(:relation, :relsub_id => 1, :relobj_id => 2, :project_id => 1)
      @modification = FactoryGirl.create(:modification, :obj => @relation, :project_id => 1)
    end
    
    it 'relation.modifications should be present' do
      @relation.modifications.should be_present
    end
    
    it 'relation.modifications should include related modifications' do
      (@relation.modifications - [@modification]).should be_blank
    end
    
    it 'modification should belongs to relation' do
      @modification.obj.should eql(@relation)
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span_sub = FactoryGirl.create(:span, :id => 1, :hid => 'span sub hid', :project => @project, :doc => @doc)
      @span_relobj = FactoryGirl.create(:span, :id => 2, :hid => 'span rel hid', :project => @project, :doc => @doc)
      @relation = FactoryGirl.create(:relation, 
      :hid => 'hid',
      :reltype => 'lexChain', 
      :relobj => @span_relobj, 
      :project => @project)
      @get_hash = @relation.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@relation[:hid])
    end
    
    it 'should set reltype as type' do
      @get_hash[:type].should eql(@relation[:reltype])
    end
    
    it 'should set end as span:end' do
      @get_hash[:subject].should eql(@span_sub[:hid])
    end
    
    it 'should set end as span:end' do
      @get_hash[:object].should eql(@span_relobj[:hid])
    end
  end
end