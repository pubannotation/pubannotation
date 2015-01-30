# encoding: utf-8
require 'spec_helper'

describe "projects/_list.html.erb" do
  before do
    @user = FactoryGirl.create(:user)
    @project = FactoryGirl.create(:project, :description => 'project description', :name => 'project name', :author => 'project author', :user => @user)
    view.stub(:projects).and_return([@project])
    view.stub(:current_user).and_return(nil)
    view.stub(:doc).and_return(nil)
    view.stub(:sortable).and_return(nil)
  end
  
  describe 'h1' do
    context 'when scope present' do
      before do
        view.stub(:scope).and_return('user_projects')
        render
      end
      
      it 'should render user project title' do
        rendered.should have_selector :h1, :content => I18n.t("views.projects.user_projects")
      end
    end
  end

  describe 'index link' do
    before do
      view.stub(:scope).and_return('user_projects')
    end

    context 'when params[:controller] == projects' do
      before do
        @params = {controller: 'projects'}
      end

      context 'when params[:action] == index' do
        before do
          @params[:action] = 'index'
        end

        context 'when params[:sort_direction] present' do
          before do
            @params[:sort_direction] = 'ASC'
            view.stub(:params).and_return(@params)
            render 
          end

          it 'should include projects_path link' do
            expect(rendered).to have_selector(:a, href: projects_path)
          end
        end

        context 'when params[:sort_direction] nil' do
          before do
            view.stub(:params).and_return(@params)
            render 
          end

          it 'should not include projects_path link' do
            expect(rendered).not_to have_selector(:a, href: projects_path)
          end
        end
      end

      context 'when params[:action] != index' do
        before do
          @params[:action] = 'show'
          view.stub(:params).and_return(@params)
          render 
        end

        it 'should include projects_path link' do
          expect(rendered).to have_selector(:a, href: projects_path)
        end
      end
    end

    context 'when params[:controller] != projects' do
      before do
        @params = {controller: 'home'}
        view.stub(:params).and_return(@params)
      end

      context 'whene @doc blank' do
        before do
          render 
        end

        it 'should include projects_path link' do
          expect(rendered).to have_selector(:a, href: projects_path)
        end
      end

      context 'whene @doc present' do
        before do
          assign :doc, FactoryGirl.create(:doc)
          render 
        end

        it 'should include projects_path link' do
          expect(rendered).not_to have_selector(:a, href: projects_path)
        end
      end
    end
  end

  describe 'counter' do
    before do
      assign :projects, [@project]
      view.stub(:projects).and_return([@project])
      view.stub(:user_signed_in?).and_return(false)
      @denotations_count_helper = 'denotations_count_helper'
      view.stub(:denotations_count_helper).and_return(@denotations_count_helper, nil)
      @relations_count_helper = 'relations_count_helper'
      view.stub(:relations_count_helper).and_return(@relations_count_helper, nil)
      view.stub(:scope).and_return(nil)
      render
    end
  
    it 'should render denotations_count_helper' do
      rendered.should include(@denotations_count_helper)
    end
    
    it 'should render relations_count_helper' do
      rendered.should include(@relations_count_helper)
    end
  end  

  describe 'annotations_projects' do
    before do
      assign :projects, [@project]
      view.stub(:scope).and_return(nil)
      assign :annotations_projects_check, true
      render
    end

    it 'should render checkbox for project annotations' do
      rendered.should have_selector(:input, class: 'annotations_projects_check', type: 'checkbox', value: @project.name)
    end
  end
end
