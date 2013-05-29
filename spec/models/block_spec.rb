# encoding: utf-8
require 'spec_helper'

describe Block do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @block = FactoryGirl.create(:block, :project => @project, :doc_id => 20)
    end
    
    it 'block should belongs to project' do
      @block.project.should eql(@project)
    end
  end

  describe 'belongs_to doc' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc)
      @block = FactoryGirl.create(:block, :project => @project, :doc => @doc)
    end
    
    it 'block should belongs to doc' do
      @block.doc.should eql(@doc)
    end
  end
  
  describe 'has_many subrels ans objrels' do
    context 'when subj and obj == Block' do
      before do
        @subj_block = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @obj_block = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj_block.id,
          :subj_type => @subj_block.class.name,
          :obj => @obj_block,
          :obj_type => @obj_block.class.to_s,
          :project_id => 2
        )
        FactoryGirl.create(:relation, :subj_id => 10, :subj_type => @subj_block.class.name, :obj_id => 1, :project_id => 2)
      end
      
      it 'block should have subrels' do
        @subj_block.subrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@subj_block.subrels - [@subrel]).should be_blank
      end
      
      it 'block should have objrels' do
        @obj_block.objrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@obj_block.objrels - [@subrel]).should be_blank
      end
    end
  end
  
  describe 'has_many objrels' do
    before do
      @block = FactoryGirl.create(:block,
        :project_id => 1,
        :doc_id => 2
      )
      @objrel = FactoryGirl.create(:block_relation,
        :obj => @block,
        :subj => FactoryGirl.create(:block, :project_id => 2, :doc_id => 1),
        :project_id => 2,
      )
      FactoryGirl.create(:relation, :obj_id => 10, :obj_type => @block.class.name, :project_id => 2)
    end
    
    it 'block should have objrels' do
      @block.objrels.should be_present
    end
    
    it 'block.objrels should have related relations' do
      (@block.objrels - [@objrel]).should be_blank
    end
  end
  
  describe 'get_hash' do
    before do
      @block = FactoryGirl.create(:block,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :category => 'category',
        :project_id => 1,
        :doc_id => 3
      )
      @get_hash = @block.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@block[:hid])
    end
    
    it 'should set begin as span:begin' do
      @get_hash[:span][:begin].should eql(@block[:begin])
    end
    
    it 'should set end as span:end' do
      @get_hash[:span][:end].should eql(@block[:end])
    end
    
    it 'category as category' do
      @get_hash[:category].should eql(@block[:category])
    end    
  end
end