# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @source_dbs = ['source_dbs']
      Doc.stub(:source_dbs).and_return(@source_dbs)
      @project_order_by = 'project_order_by'
      Project.stub(:order_by).and_return(@project_order_by)
      get :index
    end
    
    it '@source_dbs should eql Doc.source_dbs' do
      assigns[:source_dbs].should eql @source_dbs
    end
    
    it '@projects should eql Project.order_by' do
      assigns[:projects].should eql(@project_order_by)
    end
  end
end