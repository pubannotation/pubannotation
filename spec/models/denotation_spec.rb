require 'spec_helper'

describe Denotation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
    end
    
    it 'denotation.should belongs to project' do
      @denotation.project.should eql(@project)
    end
  end
  
  describe 'belongs_to doc' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :project_id => 1)
      @doc.reload
    end
    
    it 'denotation should belongs to doc' do
      @denotation.doc.should eql(@doc)
    end  
    
    it 'doc should count up doc.denotations_count' do
      @doc.denotations_count.should eql(1)
    end  
  end
  
  describe 'has_many instances' do
    before do
      @denotation = FactoryGirl.create(:denotation, :project_id => 10, :doc_id => 20)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 10) 
    end
    
    it 'denotation.instances should present' do
      @denotation.instances.should be_present
    end
    
    it 'denotation.instances should present' do
      (@denotation.instances - [@instance]).should be_blank
    end
  end
  
  describe 'has_many subrels' do
    before do
      @denotation = FactoryGirl.create(:denotation, :doc_id => 1, :project_id => 1)
      @relation = FactoryGirl.create(:relation,
        :subj_id => @denotation.id, 
        :subj_type => @denotation.class.to_s,
        :obj_id => 50, 
        :project_id => 1
      )
    end
    
    it 'denotation.resmods should preset' do
      @denotation.subrels.should be_present 
    end
    
    it 'denotation.resmods should include relation' do
      (@denotation.subrels - [@relation]).should be_blank 
    end
  end
  
  describe 'has_many objrels' do
    before do
      @denotation = FactoryGirl.create(:denotation, :doc_id => 1, :project_id => 1)
      @relation = FactoryGirl.create(:relation,
        :subj_id => 1, 
        :subj_type => 'Instance',
        :obj => @denotation, 
        :project_id => 1
      )
    end
    
    it 'denotation.objrels should preset' do
      @denotation.objrels.should be_present 
    end
    
    it 'denotation.resmods should include relation' do
      (@denotation.objrels - [@relation]).should be_blank 
    end
  end
  
  describe 'has_many insmods' do
    before do
      @denotation = FactoryGirl.create(:denotation, :doc_id => 1, :project_id => 1)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 5)
      @modification = FactoryGirl.create(:modification,
      :obj => @instance,
      :obj_type => @instance.class.to_s
      )
    end
    
    it 'denotation.insmods should present' do
      @denotation.insmods.should be_present
    end
  end
  
  describe 'get_hash' do
    before do
      @denotation = FactoryGirl.create(:denotation,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :obj => 'obj',
        :project_id => 'project_id',
        :doc_id => 3
      )
      @get_hash = @denotation.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@denotation[:hid])
    end
    
    it 'should set begin as denotation:begin' do
      @get_hash[:span][:begin].should eql(@denotation[:begin])
    end
    
    it 'should set end as denotation:end' do
      @get_hash[:span][:end].should eql(@denotation[:end])
    end
    
    it 'obj as obj' do
      @get_hash[:obj].should eql(@denotation[:obj])
    end
  end
  
  describe 'self.project_denotations_count' do
    before do
      @project = FactoryGirl.create(:project)
      @another_project = FactoryGirl.create(:project)
      @proejct_denotations_count = 2
      @proejct_denotations_count.times do
        FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
      end
    end
    
    context 'when project have denotations' do
      it 'should return denotations count' do
        Denotation.project_denotations_count(@project.id, Denotation).should eql(@proejct_denotations_count)
      end
    end
    
    context 'when project does not have denotations' do
      it 'should return denotations count' do
        Denotation.project_denotations_count(@another_project.id, Denotation).should eql(0)
      end
    end
  end
end