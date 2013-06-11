# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @serial_0 = FactoryGirl.create(:doc, :serial => 0)
      @pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0)
      @pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      @get_projects = 'get projects'
      controller.stub(:get_projects).and_return(@get_projects)
      get :index
    end
    
    it '@docs should eql Doc.where serial == 0' do
      (assigns[:docs] - [@serial_0, @pmdoc, @pmcdoc]).should be_blank
    end
    
    it '@pmdocs should eql Doc.where sourcedb == PubMed' do
      (assigns[:pmdocs] - [@pmdoc]).should be_blank
    end
    
    it '@pmcdocs should eql Doc.where sourcedb == PubMed' do
      (assigns[:pmcdocs] - [@pmcdoc]).should be_blank
    end
    
    it '@projects_num should eql get_projects.length' do
      assigns[:projects].should eql(@get_projects)
    end
  end
end