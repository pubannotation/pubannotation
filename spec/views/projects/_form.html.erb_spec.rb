# encoding: utf-8
require 'spec_helper'

describe "projects/_form.html.erb" do
  before do
    @project_user = FactoryGirl.create(:user)
    @associate_maintainer_user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :user => @project_user)
    @associate_maintainer = FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
    assign :project, @project
  end
  
  describe 'delete_link' do
    before do
      view.stub(:user_signed_in?).and_return(true)
    end
    
    context 'when destroyable_for? == true' do
      before do
        AssociateMaintainer.any_instance.stub(:destroyable_for?).and_return(true)
        current_user_stub(@project_user)
        render
      end
      
      it 'should render associate_maintainer delete link' do
        rendered.should have_selector :a, :href => project_associate_maintainer_path(@project, @associate_maintainer), 'data-method' => 'delete'
      end
    end

    context 'when destroyable_for? == true' do
      before do
        AssociateMaintainer.any_instance.stub(:destroyable_for?).and_return(false)
        current_user_stub(FactoryGirl.create(:user))
        render
      end
      
      it 'should not render associate_maintainer delete link' do
        rendered.should_not have_selector :a, :href => project_associate_maintainer_path(@project, @associate_maintainer), 'data-method' => 'delete'
      end
    end
  end

  describe 'associate maintainer field' do
    before do
      current_user_stub(FactoryGirl.create(:user))
    end
    
    context 'when project.associate_maintaines_addable_for? == true' do
      before do
        Project.any_instance.stub(:associate_maintaines_addable_for?).and_return(true)
        render
      end
      
      it 'should render associate_maintainer input' do
        rendered.should have_selector :input, :type => 'text', :id => 'username'
      end
    end

    context 'when project.associate_maintaines_addable_for? == false' do
      before do
        Project.any_instance.stub(:associate_maintaines_addable_for?).and_return(false)
        render
      end
      
      it 'should not render associate_maintainer input' do
        rendered.should_not have_selector :input, :type => 'text', :id => 'username'
      end
    end
  end
end