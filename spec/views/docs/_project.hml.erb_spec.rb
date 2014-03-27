# encoding: utf-8
require 'spec_helper'

describe "docs/_project.html.erb" do
  before do
    @project = FactoryGirl.create(:project)
    assign :project, @project
    @doc = FactoryGirl.create(:doc)
    assign :doc, @doc
    @user = FactoryGirl.create(:user)
    @annotaions_url_helper = 'annotaions url helper value'
    view.stub(:annotaions_url_helper).and_return(@annotaions_url_helper)
    stub_template 'annotations/_options' => "<%= annotation_url %>"
    view.stub(:user_signed_in?).and_return(true)
    view.stub(:current_user).and_return(@user)
  end
  
  describe '' do
    before do
      render
    end
    
    it 'should render annotations/options with annotaions_url_helper' do
      rendered.should include @annotaions_url_helper
    end
  end
  
  describe 'annotations form' do
    context 'when project.user == current_user' do
      before do
        @annotaions_form_action_helper = 'annotaions_form_action_helper'
        view.stub(:annotaions_form_action_helper).and_return(@annotaions_form_action_helper)
        @project.stub(:user).and_return(@user)
        render
      end
      
      it 'should render annotations form with annotaions_form_action_helper action' do
        rendered.should have_selector :form, action: @annotaions_form_action_helper
      end
    end
  end
end