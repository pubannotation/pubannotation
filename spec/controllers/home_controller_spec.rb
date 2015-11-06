# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @sourcedb_doc_counts = {'abc' => 2}
      Doc.stub_chain(:where, :group, :count).and_return(@sourcedb_doc_counts)
      @projects_accessible = 'top'
      @projects_top = 'top'
      Project.stub(:accessible).and_return(@projects_accessible)
      @projects_number = 1
      # Project.stub_chain(:accessible, :length).and_return(@projects_number)
      @projects_accessible.stub(:length).and_return(@projects_number)
      @projects_accessible.stub(:top).and_return(@projects_top)
    end
    
    describe 'sourcedbs page cache' do
      context 'when present' do
        before do
          controller.stub(:read_fragment).and_return(true)
        end

        it 'should not assign @sourcedb_doc_counts' do
          get :index
          assigns[:sourcedb_doc_counts].should be_nil
        end
      end

      context 'when nil' do
        it 'should assign @sourcedb_doc_counts' do
          get :index
          assigns[:sourcedb_doc_counts].should eql @sourcedb_doc_counts
        end
      end
    end
    
    it '@projects_number should eql Project.accessible.length' do
      get :index
      assigns[:projects_number].should eql(@projects_number)
    end
    
    it '@projects_top should eql Project.accessible.top' do
      Project.should_receive(:accessible)
      @projects_accessible.should_receive(:top).with(@current_user)
      get :index
    end
  end
end
