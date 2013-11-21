# encoding: utf-8
require 'spec_helper'

describe "projects/_project.html.erb" do  
  describe 'accordion' do
    before do
      @project = FactoryGirl.create(:project)
      view.stub(:user_signed_in?).and_return(false)
      view.stub(:current_user).and_return(nil)
    end

    context 'when @accordion_id present' do
      before do
        @accordion_id = 'accordion'
        assign :accordin_id, @accordion_id
        view.stub(:model).and_return(@project)
        render
      end
      
      it 'should render active id' do
        view.content_for(:javascript).should include "active: #{@accordion_id}"
      end 
    end

    context 'when @accordion_id present' do
      before do
        view.stub(:model).and_return(@project)
        render
      end
      
      it 'should not render active id' do
        view.content_for(:javascript).should_not include "active:"
      end 
    end
  end
end