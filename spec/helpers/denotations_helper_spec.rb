# encoding: utf-8
require 'spec_helper'

describe DenotationsHelper do
  describe 'spans_link_url_helper' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = {:span => {:begin => 0, :end => 10}}  
    end

    context 'when doc has_divs? = true' do
      before do 
        @doc.stub(:has_divs?).and_return(true)
      end

      it 'should return divs_spans_path link tag' do
        helper.spans_link_url_helper(@doc, @denotation).should eql(doc_sourcedb_sourceid_divs_spans_url(@doc.sourcedb, @doc.sourceid, @doc.serial, @denotation[:span][:begin], @denotation[:span][:end]))
      end
    end

    context 'when doc has_divs? = false' do
      before do 
        @doc.stub(:has_divs?).and_return(false)
      end

      it 'should return divs_spans_path link tag' do
        helper.spans_link_url_helper(@doc, @denotation).should eql(doc_sourcedb_sourceid_spans_url(@doc.sourcedb, @doc.sourceid,  @denotation[:span][:begin], @denotation[:span][:end]))
      end
    end

  end
  
  describe 'spans_link_helper' do
    before do
      @doc = FactoryGirl.create(:doc)
      @spans_link_url_helper = 'spans_link_url_helper'
      helper.stub(:spans_link_url_helper).and_return(@spans_link_url_helper)
      @denotation = {:span => {:begin => 0, :end => 10}}  
    end

    it 'should return spans_link_url_helper url' do
      helper.spans_link_helper(@doc, @denotation).should have_selector(:a, href: @spans_link_url_helper)
    end
  end

  describe 'get_project_denotations' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc)
      @params = {begin: 0, end: 5} 
      @denotations = 'denotations'
      helper.stub(:get_annotations).and_return({denotations: @denotations})
      @project_denotations = helper.get_project_denotations([@project_1, @project_2], @doc, {begin: 0, end: 0})
    end

    it 'should return project denotations' do
      @project_denotations.should =~ [{project: @project_1, denotations: @denotations}, {project: @project_2, denotations: @denotations}]
    end
  end
end
