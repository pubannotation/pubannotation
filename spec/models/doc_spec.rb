# encoding: utf-8
require 'spec_helper'

describe Doc do
  describe 'has_many spans' do
    before do
      @doc = FactoryGirl.create(:doc)
      @doc_span = FactoryGirl.create(:span, :doc => @doc)
      @another_span = FactoryGirl.create(:span, :doc => FactoryGirl.create(:doc))
    end
    
    it 'doc.spans should include related span' do
      @doc.spans.should include(@doc_span)
    end
    
    it 'doc.spans should not include unrelated span' do
      @doc.spans.should_not include(@another_span)
    end
  end
  
  describe 'has_many instances' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span = FactoryGirl.create(:span, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 1)
    end
    
    it 'span.instances should present' do
      @span.instances.should be_present
    end
    
    it 'span.instances should include instance through spans' do
      (@span.instances - [@instance]).should be_blank
    end
  end
  
  describe 'has_many :subcatrels' do
    before do
      @doc = FactoryGirl.create(:doc, :id => 2)
      @span = FactoryGirl.create(:span, :doc => @doc, :id => 3)
      @relsub = FactoryGirl.create(:span, :doc => @doc, :id => 4)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subcatrel = FactoryGirl.create(:subcatrel, :relsub_id => @relsub.id , :id => 4, :relobj => @span)
    end
    
    it 'doc.spans should include related span' do
      @doc.spans.should include(@span)
    end

    it 'doc.subcatrels should include Relation which belongs_to @doc.span' do
      @doc.subcatrels.should include(@subcatrel)
    end
  end
  
  describe 'has_many subinsrels' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span = FactoryGirl.create(:span, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 1)
      @subinsrel = FactoryGirl.create(:relation,
        :relsub_id => @instance.id,
        :relsub_type => @instance.class.to_s,
        :relobj_id => 20,
        :project_id => 30
      ) 
    end
    
    it 'doc.subinsrels should present' do
      @doc.subinsrels.should be_present
    end
    
    it 'doc.subinsrels include Relation thrhou instances' do
      (@doc.subinsrels - [@subinsrel]).should be_blank
    end
  end

  describe 'has_many insmods' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span = FactoryGirl.create(:span, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 1)
      @insmod = FactoryGirl.create(:modification, :obj => @instance, :project_id => 5)
    end
    
    it 'doc.insmods should present' do
      @doc.insmods.should be_present
    end
    
    it 'doc.insmods should present' do
      (@doc.insmods - [@insmod]).should be_blank
    end
  end
  
  describe 'has_many subcatrelmods' do
    before do
      @doc = FactoryGirl.create(:doc, :id => 2)
      @span = FactoryGirl.create(:span, :doc => @doc, :id => 3)
      @relsub = FactoryGirl.create(:span, :doc => @doc, :id => 4)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subcatrel = FactoryGirl.create(:subcatrel, :relsub_id => @relsub.id , :id => 4, :relobj => @span)
      @subcatrelmod = FactoryGirl.create(:modification, :obj => @subcatrel, :project => @project)
    end
    
    it 'doc.subcatrelmods should present' do
      @doc.subcatrels.should be_present
    end
    
    it 'doc.subcatrelmods should inclde modification through subcatrels' do
      (@doc.subcatrelmods - [@subcatrelmod]).should be_blank
    end
  end

  describe 'has_many :subinsrelmods' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span = FactoryGirl.create(:span, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @span, :project_id => 1)
      @subinsrel = FactoryGirl.create(:relation,
        :relsub_id => @instance.id,
        :relsub_type => @instance.class.to_s,
        :relobj_id => 20,
        :project_id => 30
      )
      @subinsrelmod = FactoryGirl.create(:modification,
        :obj => @subinsrel,
        :project_id => 30
      )
    end
    
    it 'doc.subinsrelmods should present' do
      @doc.subinsrelmods.should be_present
    end
    
    it 'doc.subinsrelmods should inclde modification through subcatrels' do
      (@doc.subinsrelmods - [@subinsrelmod]).should be_blank
    end
  end
  
  
  describe 'has_and_belongs_to_many projects' do
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
end