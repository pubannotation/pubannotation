# encoding: utf-8
require 'spec_helper'

describe DocsHelper do
  describe 'sourceid_index_link_helper' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb')
      @project_id = 'project_id' 
    end
    
    context 'when params[:project_id] present' do
      before do
        helper.stub(:params).and_return({:project_id => @project_id})
        @result = helper.sourceid_index_link_helper(@doc)
      end
      
      it 'should return project  sourceid index link' do
        @result.should have_selector :a, :href => sourceid_index_project_sourcedb_docs_path(@project_id, @doc.sourcedb)
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        @result = helper.sourceid_index_link_helper(@doc)
      end
      
      it 'should return sourceid index link' do
        @result.should have_selector :a, :href => doc_sourcedb_sourceid_index_path(@doc.sourcedb)
      end
    end
  end
  
  describe 'source_db_index_docs_count_helper' do
    before do
      @doc = FactoryGirl.create(:doc, sourcedb: 'sourcedb', sourceid: 'sourceid')
      @docs = ''
    end
    
    context 'when count.class == Fixnum' do
      before do
        @count = 5
        @docs.stub(:same_sourcedb_sourceid).and_return(double(count: @count))
        @result = source_db_index_docs_count_helper(@docs, @doc)
      end
      
      it 'should rerutn ' do
        @result.should eql("(#{@count})")
      end
    end
    
    context 'when count.class != Fixnum' do
      before do
        @count = '5'
        @docs.stub(:same_sourcedb_sourceid).and_return(double(count: {[] => @count}))
        @result = source_db_index_docs_count_helper(@docs, @doc)
      end
      
      it 'should rerutn ' do
        @result.should eql("(#{@count})")
      end
    end
  end

  describe 'sourcedb_options_for_select' do
    before do
      ['A', 'B'].each do |sourcedb|
        FactoryGirl.create(:doc, sourcedb: sourcedb) 
      end
    end

    it 'should return sourcedb array' do
      expect(helper.sourcedb_options_for_select).to eql([['A', 'A'], ['B', 'B']])
    end
  end
end 
