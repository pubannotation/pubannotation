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
end