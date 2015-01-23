# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @source_dbs = ['source_dbs']
      Doc.stub(:source_dbs).and_return(@source_dbs)
      @index_projects = double(:index)
      Project.stub_chain(:accessible, :index).and_return(@index_projects)
    end
    
    it '@source_dbs should eql Doc.source_dbs' do
      get :index
      assigns[:source_dbs].should eql @source_dbs
    end
    
    it '@projects should eql Project.accessible.index' do
      get :index
      assigns[:projects].should eql(@index_projects)
    end
  end
end
