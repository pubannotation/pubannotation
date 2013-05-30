# encoding: utf-8
require 'spec_helper'

describe "annotations/index.html.erb" do
  describe '' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @relation = FactoryGirl.create(:relation,
        :id => 123,
        :obj => @denotation, 
        :project => @project        
      )
      assign :relations, [@relation]
      render 
    end
    
    it 'should render relation.id' do
      # rendered.should have_selector :td, :content => @relation.id
    end
  end
end