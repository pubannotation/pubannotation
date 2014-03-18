# encoding: utf-8
require 'spec_helper'

describe "docs/_source_doc.html.erb" do
  
  describe 'show or divs show link' do
    context 'whenr params[:project_id] present' do
      before do
        @project_id = 'project_id'
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid')
        assign :source_docs, [@doc]
        view.stub(:source_doc_counter).and_return(0)
        view.stub(:source_doc).and_return(@doc)
        view.stub(:will_paginate).and_return(nil)
        view.stub(:params).and_return({:project_id => @project_id})
        view.stub(:user_signed_in?).and_return(false)
      end
      
      context 'when doc.has_divs == true' do
        before do
          @doc.stub(:has_divs?).and_return(true)
          render
        end
        
        it 'should render divs link' do
          rendered.should have_selector :a, :href => index_project_sourcedb_sourceid_divs_docs_path(@project_id, @doc.sourcedb, @doc.sourceid)
        end
      end
      
      context 'when doc.has_divs == false' do
        before do
          @doc.stub(:has_divs?).and_return(false)
          render
        end
        
        it 'should render show link' do
          rendered.should have_selector :a, :href => show_project_sourcedb_sourceid_docs_path(@project_id, @doc.sourcedb, @doc.sourceid) 
        end
      end
    end
  end
end