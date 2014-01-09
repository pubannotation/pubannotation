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
      @destroy_all_project_pmcdoc_div_annotations_path = 'destroy_all/PMC'
      view.stub(:destroy_all_project_pmcdoc_div_annotations_path).and_return(@destroy_all_project_pmcdoc_div_annotations_path)
      @destroy_all_project_pmdoc_annotations_path = 'destroy_all/PubMed'
      view.stub(:destroy_all_project_pmdoc_annotations_path).and_return(@destroy_all_project_pmdoc_annotations_path)
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
        
          context 'when params[:pmc_doc_id] present' do
            before do
              view.stub(:params).and_return(:pmcdoc_id => 1)
              render
            end
            
            it 'should render form for destroy all PMC docs in project' do
              rendered.should have_selector :form, :action => @destroy_all_project_pmcdoc_div_annotations_path
            end
          end
            
          context 'when params[:pm_doc_id] present' do
            before do
              view.stub(:params).and_return(:pmdoc_id => 1)
              render
            end
            
            it 'should render form for destroy all PubMed docs in project' do
              rendered.should have_selector :form, :action => @destroy_all_project_pmdoc_annotations_path
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