# encoding: utf-8
require 'spec_helper'

describe "annotations/index.html.erb" do
  before do
    @spans_link_helper = 'spans_link_helper'
    view.stub(:spans_link_helper).and_return(@spans_link_helper)  
  end
  
  describe 'destroy_all form' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @current_user = FactoryGirl.create(:user)
      view.stub(:current_user).and_return(@current_user)
      assign :text, '1234'
      view.stub(:destroy_all_path).and_return('destroy_all')
      @annotations_destroy_all_project_sourcedb_sourceid_divs_docs_path = 'annotations_destroy_all_project_sourcedb_sourceid_divs_docs_path'
      view.stub(:annotations_destroy_all_project_sourcedb_sourceid_divs_docs_path).and_return(@annotations_destroy_all_project_sourcedb_sourceid_divs_docs_path)
      @annotations_destroy_all_project_sourcedb_sourceid_docs_path = 'annotations_destroy_all_project_sourcedb_sourceid_docs_path'
      view.stub(:annotations_destroy_all_project_sourcedb_sourceid_docs_path).and_return(@annotations_destroy_all_project_sourcedb_sourceid_docs_path)
    end
    
    context 'when @denotations.present' do
      before do
        assign :denotations, [{:id=>"T57", :span=>{:begin=>1, :end=>2}, :obj=>"Regulation"}]
      end

      context 'when user_signed_in? is true' do
        before do
          view.stub(:user_signed_in?).and_return(true)
        end
        
        context 'when project.user != current_user' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
            view.stub(:params).and_return(:pmcdoc_id => 1)
            assign :project, @project
            render
          end
          
          it 'should not render destroy_all doc form' do
            rendered.should_not have_selector :form
          end          
        end
        
        context 'when project.user == current_user' do
          before do
            @project = FactoryGirl.create(:project, :user => @current_user, :name => "project_name")
            assign :project, @project
          end
        
          context 'when params[:div_id] present' do
            before do
              view.stub(:params).and_return({:div_id => 1, :sourcedb => 'sourcedb', :sourceid => 123})
              render
            end
            
            it 'should render form for destroy all div docs in project' do
              rendered.should have_selector :form, :action => @annotations_destroy_all_project_sourcedb_sourceid_divs_docs_path
            end
          end
            
          context 'when params[:div_id] blank' do
            before do
              view.stub(:params).and_return({:sourcedb => 'sourcedb', :sourceid => 123})
              render
            end
            
            it 'should render form for destroy all PubMed docs in project' do
              rendered.should have_selector :form, :action => @annotations_destroy_all_project_sourcedb_sourceid_docs_path
            end
          end
        end
      end
      
      context 'when user_signed_in? is false' do
        before do
          view.stub(:params).and_return(:pmcdoc_id => 1)
          view.stub(:user_signed_in?).and_return(false)
          render
        end
        
        it 'should not render destroy_all doc form' do
          rendered.should_not have_selector :form
        end
      end
    end
    
    context 'when @denotations.present == false' do
      before do
        assign :denotations, nil
        view.stub(:params).and_return(:pmcdoc_id => 1)
        render
      end
      
      it 'should not render destroy_all doc form' do
        rendered.should_not have_selector :form
      end
    end
  end
end