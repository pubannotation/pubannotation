# encoding: utf-8
require 'spec_helper'

describe RelationsController do  
  describe 'sql' do
    before do
      @sql_find = ['Denotation sql_find']      
    end
    
    context 'when params[:project_id] present' do
      before do
        Relation.stub(:sql_find).and_return(@sql_find)
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
      end
      
      context 'when project present' do
        before do
          get :sql, :project_id => @project.name, :sql => 'select * from relations;'
        end
        
        it 'should assign project_relations_sql_path as @search_path' do
          assigns[:search_path] = project_relations_sql_path
        end
        
        it 'should assign Relation.sql_find as @denotations' do
          assigns[:relations].should eql(@sql_find)
        end
      end

      context 'when project blank' do
        before do
          get :sql, :project_id => 'invalid', :sql => 'select * from relations;'
        end
        
        it 'should assign project_pmrelations_sql_path as @search_path' do
          assigns[:search_path] = project_relations_sql_path
        end
        
        it '@redirected should be true' do
          assigns[:redirected].should be_true
        end
                
        it 'should redirect_to project_pmrelations_sql_path' do
          response.should redirect_to(relations_sql_path)
        end
      end
    end
    
    context 'when invalid SQL' do
      before do
        get :sql, :sql => 'select - relationss;'
      end
      
      it 'should assign flash[:notice]' do
        flash[:notice].should be_present
      end
    end
  end
end
