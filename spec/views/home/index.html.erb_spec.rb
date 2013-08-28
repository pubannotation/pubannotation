# encoding: utf-8
require 'spec_helper'

describe "home/index.html.erb" do
  before do
    assign :pmdocs, []
    assign :pmcdocs, []
    current_user_stub(nil)
  end
  
  describe 'projects' do
    before do
      @project = FactoryGirl.create(:project, :description => '')
      assign :user_projects, []
      assign :associate_maintaiain_projects, []
      assign :projects, []
      render
    end
    
    context 'when @user_projects present' do
      before do
        assign :user_projects, [@project]
        render
      end
      it 'should render template' do
        rendered.should render_template('projects/_list')
      end
    end
    
    context 'when @associate_maintaiain_projects present' do
      before do
        assign :associate_maintaiain_projects, [@project]
        render
      end
      it 'should render template' do
        rendered.should render_template('projects/_list')
      end
    end
    
    context 'when @projects present' do
      before do
        assign :projects, [@project]
        render
      end
      it 'should render template' do
        rendered.should render_template('projects/_list')
      end
    end
  end
end