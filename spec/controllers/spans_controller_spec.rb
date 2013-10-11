# encoding: utf-8
require 'spec_helper'

describe SpansController do
  describe 'sql' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @sql_find = ['Denotation sql_find']
    end

    context 'when params[:project_id] present' do
      before do
        Denotation.stub(:sql_find).and_return(@sql_find)
        @project = FactoryGirl.create(:project, :name => 'spans project')
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
      end
      
      context 'when project present' do
        before do
          get :sql, :project_id => @project.name, :sql => 'select * from denotations;'
        end
        
        it 'should assign project_spans_sql_path as @search_path' do
          assigns[:search_path] = project_spans_sql_path
        end
        
        it 'should assign Denotation.sql_find as @denotations' do
          assigns[:denotations].should eql(@sql_find)
        end
      end
      
      context 'when project blank' do
        before do
          get :sql, :project_id => 'invalid', :sql => 'select * from denotations;'
        end
        
        it 'should assign spans_sql_path as @search_path' do
          assigns[:search_path] = spans_sql_path
        end
        
        it 'should redirect_to spans_sql_path' do
          response.should redirect_to(spans_sql_path)
        end
      end
    end
    
    context 'when invalid SQL' do
      before do
        get :sql, :project_id => 'invalid', :sql => 'select * denotations;'
      end
      
      it 'should assign flash[:notice]' do
        flash[:notice].should be_present
      end
    end
  end
end