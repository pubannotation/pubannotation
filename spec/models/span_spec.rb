require 'spec_helper'

describe Span do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @span = FactoryGirl.create(:span, :project => @project, :doc => FactoryGirl.create(:doc))
    end
    
    it 'span.should belongs to project' do
      @span.project.should eql(@project)
    end
  end
  
  describe 'belongs_to doc' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span = FactoryGirl.create(:span, :doc => @doc)
    end
    
    it 'span should belongs to doc' do
      @span.doc.should eql(@doc)
    end  
  end
  
  describe 'has_many instances' do
    before do
      @span = FactoryGirl.create(:span, :project_id => 10, :doc_id => 20)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 10) 
    end
    
    it 'span.instances should present' do
      @span.instances.should be_present
    end
    
    it 'span.instances should present' do
      (@span.instances - [@instance]).should be_blank
    end
  end
  
  describe 'has_many subrels' do
    before do
      @span = FactoryGirl.create(:span, :doc_id => 1)
      @relation = FactoryGirl.create(:relation,
        :relsub_id => @span.id, 
        :relsub_type => @span.class.to_s,
        :relobj_id => 50, 
        :project_id => 1
      )
    end
    
    it 'span.resmods should preset' do
      @span.subrels.should be_present 
    end
    
    it 'span.resmods should include relation' do
      (@span.subrels - [@relation]).should be_blank 
    end
  end
  
  describe 'has_many objrels' do
    before do
      @span = FactoryGirl.create(:span, :doc_id => 1)
      @relation = FactoryGirl.create(:relation,
        :relsub_id => 1, 
        :relsub_type => 'Instance',
        :relobj => @span, 
        :project_id => 1
      )
    end
    
    it 'span.objrels should preset' do
      @span.objrels.should be_present 
    end
    
    it 'span.resmods should include relation' do
      (@span.objrels - [@relation]).should be_blank 
    end
  end
  
  describe 'has_many insmods' do
    before do
      @span = FactoryGirl.create(:span, :doc_id => 1)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 5)
      @modification = FactoryGirl.create(:modification,
      :modobj => @instance,
      :modobj_type => @instance.class.to_s
      )
    end
    
    it 'span.insmods should present' do
      @span.insmods.should be_present
    end
  end
  
  describe 'has_many relmods' do
    before do
      @span = FactoryGirl.create(:span, :doc_id => 1)
      @relation = FactoryGirl.create(:relation,
        :relobj_id => 1, 
        :project_id => 1
      )
      @modification = FactoryGirl.create(:modification,
      :modobj => @relation,
      :modobj_type => @relation.class.to_s
      )
    end
    
    it 'span.insmods should present' do
      pending 'relation something wrong'
    end
  end
  
  describe 'get_hash' do
    before do
      @span = FactoryGirl.create(:span,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :category => 'category',
        :project_id => 'project_id',
        :doc_id => 3
      )
      @get_hash = @span.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@span[:hid])
    end
    
    it 'should set begin as span:begin' do
      @get_hash[:span][:begin].should eql(@span[:begin])
    end
    
    it 'should set end as span:end' do
      @get_hash[:span][:end].should eql(@span[:end])
    end
    
    it 'category as category' do
      @get_hash[:category].should eql(@span[:category])
    end
  end
end