# encoding: utf-8
require 'spec_helper'

describe "annotations/index.html.erb" do
  describe 'destroy_all form' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @current_user = FactoryGirl.create(:user)
      view.stub(:current_user).and_return(@user)
      @project = FactoryGirl.create(:project, :user => @current_user, :name => "project_name")
      assign :project, @project
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      assign :text, '1234'
      assign :denotations, [{:id=>"T57", :span=>{:begin=>1, :end=>2}, :obj=>"Regulation"}]
      view.stub(:user_signed_in?).and_return(true)
      view.stub(:params).and_return(:pmcdoc_id => 1)
      @destroy_all_project_pmcdoc_div_annotations_path = 'destroy_all/PMC'
      view.stub(:destroy_all_project_pmcdoc_div_annotations_path).and_return(@destroy_all_project_pmcdoc_div_annotations_path)
      @destroy_all_project_pmdoc_annotations_path = 'destroy_all/PubMed'
      view.stub(:destroy_all_project_pmdoc_annotations_path).and_return(@destroy_all_project_pmdoc_annotations_path)
      render
    end
    
    it '' do
      #rendered.should have_selector :form, :action => @destroy_all_project_pmcdoc_div_annotations_path
    end
  end
end