require 'spec_helper'

describe Relation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :obj_id => 10, :project => @project)
    end
    
    it 'relation belongs to project' do
      @relation.project.should eql(@project)
    end
  end
  
  describe 'belongs_to subj polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @obj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
    end
    
    context 'Span' do
      before do
        @subj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :subj_id => @subj.id, :subj_type => @subj.class.to_s, :obj => @obj, :project => @project)
      end
      
      it 'relation.subj should equal Span' do
        @relation.subj.should eql(@subj)
      end
    end

    context 'Insaan' do
      before do
        @subj = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :subj_id => @subj.id, :subj_type => @subj.class.to_s, :obj => @obj, :project => @project)
      end
      
      it 'relation.subj should equal Instance' do
        @relation.subj.should eql(@subj)
      end
    end
  end
  
  describe 'belongs_to obj polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @subj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
    end
    
    context 'Span' do
      before do
        @obj = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :subj => @subj, :obj => @obj, :obj_type => @obj.class.to_s, :project => @project)
      end
      
      it 'relation.obj should equal Span' do
        @relation.obj.should eql(@obj)
      end
    end

    context 'Insaan' do
      before do
        @obj = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :subj => @subj, :obj => @obj, :obj_type => @obj.class.to_s, :project => @project)
      end
      
      it 'relation.subj should equal Instance' do
        @relation.obj.should eql(@obj)
      end
    end
  end
  
  describe 'has_many modifications' do
    before do
      @relation = FactoryGirl.create(:relation, :subj_id => 1, :obj_id => 2, :project_id => 1)
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
      @span_obj = FactoryGirl.create(:span, :id => 2, :hid => 'span rel hid', :project => @project, :doc => @doc)
      @relation = FactoryGirl.create(:relation, 
      :hid => 'hid',
      :pred => 'lexChain', 
      :obj => @span_obj, 
      :project => @project)
      @get_hash = @relation.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@relation[:hid])
    end
    
    it 'should set pred as type' do
      @get_hash[:pred].should eql(@relation[:pred])
    end
    
    it 'should set end as span:end' do
      @get_hash[:subj].should eql(@span_sub[:hid])
    end
    
    it 'should set end as span:end' do
      @get_hash[:obj].should eql(@span_obj[:hid])
    end
  end
  
  describe 'validate' do
    context 'when subj == Span and obj == Instance' do
      before do
        @subj = FactoryGirl.create(:span,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:instance,
          :project_id => 1,
          :obj_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
      end
      
      it 'relation.subj should equal Span' do
        @subrel.subj.should eql(@subj)
      end
      
      it 'relation.obj should equal Instance' do
        @subrel.obj.should eql(@obj)
      end
    end    

    context 'when subj == Instance and obj == Span' do
      before do
        @subj = FactoryGirl.create(:instance,
          :project_id => 1,
          :obj_id => 2
        )
        @obj = FactoryGirl.create(:span,
          :project_id => 1,
          :doc_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
      end
      
      it 'relation.subj should equal Instance' do
        @subrel.subj.should eql(@subj)
      end
      
      it 'relation.subj should equal Span' do
        @subrel.obj.should eql(@obj)
      end
    end    

    context 'when subj and obj == Block' do
      before do
        @subj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
        FactoryGirl.create(:relation, :subj_id => 10, :subj_type => @subj.class.name, :obj_id => 1, :project_id => 2)
      end
      
      it 'block should have subrels' do
        @subj.subrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@subj.subrels - [@subrel]).should be_blank
      end
      
      it 'block should have objrels' do
        @obj.objrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@obj.objrels - [@subrel]).should be_blank
      end
    end

    context 'when subj == Block subj != Block' do
      before do
        @subj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:span,
          :project_id => 1,
          :doc_id => 2
        )
      end
      
      it 'should raise error' do
        lambda { 
          FactoryGirl.create(:relation,
            :subj_id => @subj.id,
            :subj_type => @subj.class.name,
            :obj => @obj,
            :obj_type => @obj.class.to_s,
            :project_id => 2
          )
        }.should raise_error
      end
    end

    context 'when subj != Block obj == Block' do
      before do
        @subj = FactoryGirl.create(:span,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
      end
      
      it 'should raise error' do
        lambda { 
          FactoryGirl.create(:relation,
            :subj_id => @subj.id,
            :subj_type => @subj.class.name,
            :obj => @obj,
            :obj_type => @obj.class.to_s,
            :project_id => 2
          )
        }.should raise_error
      end
    end
  end
end