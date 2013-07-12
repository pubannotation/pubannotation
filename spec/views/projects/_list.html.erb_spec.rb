# encoding: utf-8
require 'spec_helper'

describe "projects/_list.html.erb" do
  before do
    @user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :description => 'project description', :name => 'project name', :author => 'project author', :user => @user)
  end

  describe 'counter' do
    before do
      assign :projects, [@project]
      view.stub(:user_signed_in?).and_return(false)
      @denotations_count_helper = 'denotations_count_helper'
      view.stub(:denotations_count_helper).and_return(@denotations_count_helper)
      @relations_count_helper = 'relations_count_helper'
      view.stub(:relations_count_helper).and_return(@relations_count_helper)
      render
    end
  
    it 'should render denotations_count_helper' do
      rendered.should include(@denotations_count_helper)
    end
    
    it 'should render relations_count_helper' do
      rendered.should include(@relations_count_helper)
    end
  end  
end