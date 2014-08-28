# encoding: utf-8
require 'spec_helper'

describe "projects/_list.html.erb" do
  before do
    @user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :description => 'project description', :name => 'project name', :author => 'project author', :user => @user)
    view.stub(:projects).and_return([@project])
    view.stub(:current_user).and_return(nil)
    view.stub(:doc).and_return(nil)
    view.stub(:sortable).and_return(nil)
  end
  
  describe 'h1' do
    context 'when scope present' do
      before do
        view.stub(:scope).and_return('user_projects')
        render
      end
      
      it 'should render user project title' do
        rendered.should have_selector :h1, :content => I18n.t("views.projects.user_projects")
      end
    end
  end

  describe 'counter' do
    before do
      assign :projects, [@project]
      view.stub(:projects).and_return([@project])
      view.stub(:user_signed_in?).and_return(false)
      @denotations_count_helper = 'denotations_count_helper'
      view.stub(:denotations_count_helper).and_return(@denotations_count_helper, nil)
      @relations_count_helper = 'relations_count_helper'
      view.stub(:relations_count_helper).and_return(@relations_count_helper, nil)
      view.stub(:scope).and_return(nil)
      render
    end
  
    it 'should render denotations_count_helper' do
      rendered.should include(@denotations_count_helper)
    end
    
    it 'should render relations_count_helper' do
      rendered.should include(@relations_count_helper)
    end
  end  

  describe 'annotations_projects' do
    before do
      assign :projects, [@project]
      view.stub(:scope).and_return(nil)
      assign :annotations_projects_check, true
      render
    end

    it 'should render checkbox for project annotations' do
      rendered.should have_selector(:input, class: 'annotations_projects_check', type: 'checkbox', value: @project.name)
    end
  end
end
