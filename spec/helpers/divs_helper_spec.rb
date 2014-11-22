# encoding: utf-8
require 'spec_helper'

describe DivsHelper do
  describe 'div_link_helper' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '123', :serial => 0)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) 
      @pmcdoc_id = 123456
    end    
    
    context 'when project present' do
      context 'when params[:pmcdoc_id] blank' do
        before do
          helper.stub(:params).and_return({:project_id => @project.name, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid})
          @result = helper.div_link_helper(@project, @doc)
        end
      
        it 'should return show_project_sourcedb_sourceid_divs_docs_path' do
          @result.should have_selector :a, :href => show_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end        
      end
    end
    
    context 'when project blank' do
      context 'when params[:pmcdoc_id] blank' do
        before do
          helper.stub(:params).and_return({:project_id => @project.name, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid})
          @result = helper.div_link_helper(nil, @doc)
        end
      
        it 'should return doc_sourcedb_sourceid_divs_show_path' do
          @result.should have_selector :a, :href => doc_sourcedb_sourceid_divs_show_path(@doc.sourcedb, @doc.sourceid, @doc.serial)
        end        
      end
    end
  end
end
