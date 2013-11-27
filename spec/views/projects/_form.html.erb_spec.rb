# encoding: utf-8
require 'spec_helper'

describe "projects/_form.html.erb" do
  before do
    @project_user = FactoryGirl.create(:user)
    @associate_maintainer_user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :user => @project_user)
    @associate_maintainer = FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
    assign :project, @project
    view.stub(:model).and_return(@project)
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
  
  describe 'usernames' do
    context 'when project.associate_maintenes_addable_for? = true' do
      before do
        Project.any_instance.stub(:associate_maintainers_addable_for?).and_return(true)
        @user = FactoryGirl.create(:user)
        current_user_stub(@user)
      end
      
      context 'when params[:usernames] present' do
        before do
          @usernames = ['user1', 'user2']
          view.stub(:params).and_return({:usernames => @usernames})
          render
        end
        
        it 'shoud render usernames input field' do
          rendered.should have_selector :input, :type => 'hidden', :id => 'usernames[]', :value => @usernames[0]
        end
      end
      
      context 'when params[:usernames] blank' do
        before do
          render
        end
        
        it 'shoud not render usernames input field' do
          rendered.should_not have_selector :input, :type => 'hidden', :id => 'usernames[]'
        end
      end
    end
  end

  describe 'associate maintainer field' do
    before do
      current_user_stub(FactoryGirl.create(:user))
    end
    
    context 'when project.associate_maintainers_addable_for? == true' do
      before do
        Project.any_instance.stub(:associate_maintainers_addable_for?).and_return(true)
        render
      end
      
      it 'should render associate_maintainer input' do
        rendered.should have_selector :input, :type => 'text', :id => 'username'
      end
    end

    context 'when project.associate_maintainers_addable_for? == false' do
      before do
        Project.any_instance.stub(:associate_maintainers_addable_for?).and_return(false)
        render
      end
      
      it 'should not render associate_maintainer input' do
        rendered.should_not have_selector :input, :type => 'text', :id => 'username'
      end
    end
  end
  
  describe 'associate_projects' do
    before do
      current_user_stub(FactoryGirl.create(:user))  
    end
    
    context 'when import present' do
      before do
        view.stub(:params).and_return({
          :associate_projects => {
            :name => {'0' => 'associate 0', '1' => 'associate 1'},
            :import => {'1' => 'true'}
          }
        })
        render
      end
      
      it 'should render associate project hidden tag' do
        rendered.should have_selector :input, :type => 'hidden', :value => 'associate 0', :id => 'associate_projects_name_0' 
      end
      
      it 'should render associate project import not checked hidden import tag' do
        rendered.should have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_0'
      end
      
      it 'should not render associate project import not checked hidden import tag checked' do
        rendered.should_not have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_0', :checked => 'checked' 
      end
      
      it 'should render associate project hidden tag' do
        rendered.should have_selector :input, :type => 'hidden', :value => 'associate 1', :id => 'associate_projects_name_1' 
      end
      
      it 'should render associate project import checked  hidden import tag checked' do
        rendered.should have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_1', :checked => 'checked'  
      end
    end
    
    context 'when import blank' do
      before do
        view.stub(:params).and_return({
          :associate_projects => {
            :name => {'0' => 'associate 0', '1' => 'associate 1'},
          }
        })
        render
      end
      
      it 'should render associate project hidden tag' do
        rendered.should have_selector :input, :type => 'hidden', :value => 'associate 0', :id => 'associate_projects_name_0' 
      end
      
      it 'should render associate project import not checked hidden import tag' do
        rendered.should have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_0'
      end
      
      
      it 'should not render associate project import not checked hidden import tag' do
        rendered.should_not have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_0', :checked => 'checked' 
      end
      
      it 'should render associate project hidden tag' do
        rendered.should have_selector :input, :type => 'hidden', :value => 'associate 1', :id => 'associate_projects_name_1' 
      end
      
      it 'should render associate project import not checked hidden import tag' do
        rendered.should have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_1'
      end
      
      
      it 'should not render associate project import not checked  hidden import tag checked' do
        rendered.should_not have_selector :input, :type => 'checkbox', :value => 'true', :id => 'associate_projects_import_1', :checked => 'checked'  
      end
    end
  end
end