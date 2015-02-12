# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @sourcedbs = ['sourcedbs']
      Doc.stub(:sourcedbs).and_return(@sourcedbs)
      @index_projects = double(:index)
      Project.stub_chain(:accessible, :index).and_return(@index_projects)
    end
    
    it '@sourcedbs should eql Doc.sourcedbs' do
      get :index
      assigns[:sourcedbs].should eql @sourcedbs
    end
    
    it '@projects should eql Project.accessible.index' do
      get :index
      assigns[:projects].should eql(@index_projects)
    end
  end
end
