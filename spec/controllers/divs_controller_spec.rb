# encoding: utf-8
require 'spec_helper'

describe DivsController do
  describe 'index' do
    before do
      @pmcdoc_id = 'sourceid'
      @doc_pmc_sourceid = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @pmcdoc_id)
      @doc_not_pmc = FactoryGirl.create(:doc, :sourcedb => 'AAA', :sourceid => @pmcdoc_id)
      @project_id = 'project_id'
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => @project_id)
    end
    
    context 'when params[:project_id] present' do
      context 'when format html' do
        before do
          get :index, :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
        end
        
        it '@docs should include only sourcedb and sourceid match' do
          assigns[:docs].should include(@doc_pmc_sourceid)      
          assigns[:docs].should_not include(@doc_not_pmc) 
        end
        
        it '@project_name should be same as params[:project_id]' do
          assigns[:project_name].should eql(@project_id)
        end
        
        it 'should render template' do
          response.should render_template('index')
        end
        
        it 'should assign project' do
          assigns[:project].should eql(@project)
        end
      end
  
      context 'when format json' do
        before do
          get :index, :format => 'json', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:docs].to_json)
        end
      end
    end
  end
  
  describe 'show' do
    before do
      @id = 'id'
      @pmcdoc_id = 'pmc doc id'
      @asciitext = 'aschii text'
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 123, :serial => 0)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @get_doc_notice = 'get doc notice'
    end

    context 'when params[:project_id] exists' do
      before do
        @project_id = 'project id'
        @get_project_notice = 'get project notice'
      end
      
      context 'when get_project returns project' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
        end
        
        context 'get_doc return doc' do
          context 'when format html' do
            before do
              controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
            end
            
            it '@text should same as @doc.body' do
              assigns[:text].should eql(@doc.body)
            end
            
            it 'should set get_doc notice as flash[:notice]' do
              flash[:notice].should eql(@get_doc_notice)  
            end
            
            it 'should render template' do
              response.should render_template('docs/show')
            end
          end

          context 'when encoding ascii' do
            before do
              controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
              @asciitext = 'ascii'
              controller.stub(:get_ascii_text).and_return(@asciitext)
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id, :encoding => 'ascii'
            end
            
            it '@text should getr_ascii_text' do
              assigns[:text].should eql(@asciitext)
            end
          end

          context 'when format json' do
            before do
              controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id, :format => 'json'
            end
            
            it 'should render template' do
              response.should render_template('docs/show')
            end
          end
        end     
      end
      
      context 'when get_project does not returns project' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
        end
        
        context 'when format html' do
          before do
            @refrerer = root_path
            request.env["HTTP_REFERER"] = @refrerer
            get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it '@doc should be nil' do
            assigns[:doc].should be_nil
          end  
          
          it 'should redirect to back' do
            response.should redirect_to(@refrerer)
          end
          
          it 'should set flash[:notice]' do
            flash[:notice].should eql(@get_project_notice)
          end
        end  
        
        context 'when format json' do
          before do
            get :show, :format => 'json', :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
        
        context 'when format txt' do
          before do
            get :show, :format => 'txt', :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
      end
    end
    
    context 'when params[:project_id] does not exists' do
      before do
        controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
        @get_projects_notice = 'get projects notice'
        controller.stub(:get_projects).and_return([@project, @get_projects_notice])
        controller.stub(:get_ascii_text).and_return(@asciitext)
        @project_1 = FactoryGirl.create(:project, user: @current_user, name: 'project1', author: 'AAA BBB')
        @doc.projects << @project_1
        @project_2 = FactoryGirl.create(:project, user: @current_user, name: 'project2', author: 'BBB CCC')
        @doc.projects << @project_2
      end

      context 'when params[:sort_key] present' do
        before do
          controller.stub(:flash).and_return({:sort_order=> [['projects.id', 'DESC']]})
          get :show, :sort_key => 'name', :sort_direction => 'DESC', :sort_order => 'DESC', :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @doc.serial
        end

        it 'should order @projects by sort key, order' do
          assigns[:projects][0].should eql @project_2
        end

        it 'should order @projects by sort key, order' do
          assigns[:projects][1].should eql @project_1
        end
      end

      context 'when params[:sort_key] blank' do
        before do
          controller.stub(:flash).and_return({:sort_order=> [['projects.id', 'DESC']]})
          get :show, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @doc.serial
        end

        it 'should order @projects by name ASC author ASC' do
          assigns[:projects][0].should eql @project_1
        end

        it 'should order @projects by name ASC author ASC' do
          assigns[:projects][1].should eql @project_2
        end
      end
    end
  end
end
