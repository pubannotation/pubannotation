# encoding: utf-8
require 'spec_helper'

describe AssociateMaintainersController do
  before do
    @project_user = FactoryGirl.create(:user)
    @associate_maintainer_user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :user => @project_user, :name => "maintainer test project")
    @associate_maintainer = FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
  end
  
  describe 'destroy' do
    context 'when maintainer destroyed' do
      before do
        current_user_stub(@project_user)
        delete :destroy, :format => :html, :project_id => @project.id, :id => @associate_maintainer.id 
      end
      
      it 'should redirect to edit project path' do
        response.should redirect_to(edit_project_path(@associate_maintainer.project.name))
      end
    end
    
    context 'when associate maintainer destroyed' do
      before do
        current_user_stub(@associate_maintainer_user)
        delete :destroy, :format => :html, :project_id => @project.id, :id => @associate_maintainer.id 
      end
      
      it 'should redirect to edit project path' do
        response.should redirect_to(project_path(@associate_maintainer.project.name))
      end
    end
  end
  
  describe 'destroyable?' do
    before do
      @render_status_error = 'render_status_error'
      controller.stub(:render_status_error).and_return(@render_status_error)
      controller.stub(:params).and_return({:id => @associate_maintainer.id})
      controller.stub(:current_user).and_return(nil)
    end
    
    context 'when destroyable_for? == true' do
      before do
        AssociateMaintainer.any_instance.stub(:destroyable_for?).and_return(true)
        @result = controller.destroyable?
      end
      
      it 'should return nil' do
        @result.should be_nil
      end  
    end

    context 'when destroyable_for? == false' do
      before do
        AssociateMaintainer.any_instance.stub(:destroyable_for?).and_return(false)
        @result = controller.destroyable?
      end
      
      it 'should return nil' do
        @result.should eql(@render_status_error)
      end  
    end
  end
end