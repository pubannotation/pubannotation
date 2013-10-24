# encoding: utf-8
require 'spec_helper'

describe DivsController do
  describe 'index' do
    before do
      @pmcdoc_id = 'sourceid'
      @doc_pmc_sourceid = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @pmcdoc_id)
      @doc_not_pmc = FactoryGirl.create(:doc, :sourcedb => 'AAA', :sourceid => @pmcdoc_id)
      @project_id = 'project_id'
      @project = FactoryGirl.create(:project, :name => @project_id)
    end

    context 'when project_id.present' do
      context 'when format html' do
        before do
          get :index, :pmcdoc_id => @pmcdoc_id, :project_id => @project_id
        end
        
        it '@docs should include only sourcede == PMC and sourceid == params[:pmcdoc_id]' do
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
          get :index, :format => 'json', :pmcdoc_id => @pmcdoc_id, :project_id => @project_id
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:docs].to_json)
        end
      end
    end
    
    context 'when sproject_id.present' do
      before do
        @sproject_id = 'sproject_id'
        @sproject = FactoryGirl.create(:sproject, :name => @sproject_id)
        get :index, :pmcdoc_id => @pmcdoc_id, :sproject_id => @sproject_id
      end
      
      it 'should assign project_name' do
        assigns[:project_name].should eql(@sproject_id)
      end
      
      it 'should assign sproject' do
        assigns[:sproject].should eql(@sproject)
      end
    end
  end

  describe 'spans' do
    before do
      @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
      @project = 'project'
      @projects = 'projects'
      @sproject = 'sproject'
      controller.stub(:get_sproject).and_return([@sproject, nil])
      controller.stub(:get_project).and_return([@project, nil])
      @doc.stub(:spans_projects).and_return(@projects)
      controller.stub(:get_doc).and_return([@doc, nil])
      @spans = 'SPANS'
      @prev_text = 'PREV'
      @next_text = 'NEXT'
      @doc.stub(:spans).and_return([@spans, @prev_text, @next_text])
    end
    
    context 'when params[:project_id] present' do
      context 'when format html' do
        before do
          get :spans, :project_id => 1, :pmcdoc_id => @doc.sourceid, :id => 1, :begin => 1, :end => 5
        end
        
        it 'should assign @project' do
          assigns[:project].should eql(@project)
        end
        
        it 'should not assign' do
          assigns[:projects].should be_nil
        end
        
        it 'should assign @doc' do
          assigns[:doc].should eql(@doc)
        end
        
        it 'should assign @spans' do
          assigns[:spans].should eql(@spans)
        end
        
        it 'should assign @prev_text' do
          assigns[:prev_text].should eql(@prev_text)
        end
        
        it 'should assign @next_text' do
          assigns[:next_text].should eql(@next_text)
        end
        
        it 'should render template' do
          response.should render_template('docs/spans')
        end
      end

      context 'when format json' do
        before do
          get :spans, :format => 'json', :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
        end
      end
    end
    
    context 'when params[:sproject_id] present' do
      context 'when format html' do
        before do
          get :spans, :sproject_id => 1, :pmcdoc_id => @doc.sourceid, :id => 1, :begin => 1, :end => 5
        end
        
        it '@project should be_nil' do
          assigns[:project].should be_nil
        end
        
        it 'should assign @sproject' do
          assigns[:sproject].should eql(@sproject)
        end
        
        it 'should assign @projects' do
          assigns[:projects].should eql(@projects)
        end
        
        it 'should assign @doc' do
          assigns[:doc].should eql(@doc)
        end
        
        it 'should assign @spans' do
          assigns[:spans].should eql(@spans)
        end
        
        it 'should assign @prev_text' do
          assigns[:prev_text].should eql(@prev_text)
        end
        
        it 'should assign @next_text' do
          assigns[:next_text].should eql(@next_text)
        end
        
        it 'should render template' do
          response.should render_template('docs/spans')
        end
      end

      context 'when format json' do
        before do
          get :spans, :format => 'json', :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
        end
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        get :spans, :pmcdoc_id => @doc.sourceid, :id => 1, :begin => 1, :end => 5
      end
      
      it 'should not assign @project' do
        assigns[:project].should be_nil
      end
      
      it 'should assign @projects' do
        assigns[:projects].should eql(@projects)
      end
    end
  end

  describe 'annotations' do
    before do
      @project = FactoryGirl.create(:project, :name => 'project_name')
      controller.stub(:get_project).and_return(@project, 'notice')
      @doc = FactoryGirl.create(:doc)
      controller.stub(:get_doc).and_return(@doc, 'notice')
      @projects = [@project]
      controller.stub(:get_projects).and_return(@projects)
      @spans = 'spans' 
      @prev_text = 'prevx text'
      @next_text = 'next text'
      Doc.any_instance.stub(:spans).and_return([@spans, @prev_text, @next_text])
      @annotations ={
        :text => "text",
        :denotations => "denotations",
        :instances => "instances",
        :relations => "relations",
        :modifications => "modifications"
      }
      controller.stub(:get_annotations).and_return(@annotations)
    end

    context 'when params[:project_id] present' do
      before do
        get :annotations, :project_id => @project.name, :pmcdoc_id => @doc.id, :id => 1, :begin => 1, :end => 10
      end
      
      it 'should assign @project' do
        assigns[:project].should eql(@project)
      end
      
      it 'should assign @doc' do
        assigns[:doc].should eql(@doc)
      end
      
      it 'should_not assign @projects' do
        assigns[:projects].should be_nil
      end
      
      it 'should assign @spans' do
        assigns[:spans].should eql(@spans)
      end
      
      it 'should assign @prev_text' do
        assigns[:prev_text].should eql(@prev_text)
      end
      
      it 'should assign @next_text' do
        assigns[:next_text].should eql(@next_text)
      end
      
      it 'should assign @denotations' do
        assigns[:denotations].should eql(@annotations[:denotations])
      end
      
      it 'should assign @instances' do
        assigns[:instances].should eql(@annotations[:instances])
      end
      
      it 'should assign @relations' do
        assigns[:relations].should eql(@annotations[:relations])
      end
      
      it 'should assign @modifications' do
        assigns[:modifications].should eql(@annotations[:modifications])
      end
    end
    
    # /pmcdocs/:pmcdoc_id/divs/:id/spans/:begin-:end/annotations(.:format)
    context 'when params[:project_id] blank' do
      context 'when format html' do
        before do
          get :annotations, :pmcdoc_id => @doc.id, :id => 1, :begin => 1, :end => 10
        end
        
        it 'should not assign @project' do
          assigns[:project].should be_nil
        end
        
        it 'should assign @doc' do
          assigns[:doc].should eql(@doc)
        end
      end
      
      context 'when format html' do
        before do
          get :annotations, :format => 'json', :pmcdoc_id => @doc.id, :id => 1, :begin => 1, :end => 10
        end
        
        it 'should render annotations to json' do
          response.body.should eql(@annotations.to_json)
        end
      end
    end
  end
  
  describe 'show' do
    before do
      @id = 'id'
      @pmcdoc_id = 'pmc doc id'
      @asciitext = 'aschii text'
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project)
      @get_doc_notice = 'get doc notice'
    end
    
    context 'when params[:project_id] does not exists' do
      context 'when encoding ascii' do
        before do
          controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
          @get_projects_notice = 'get projects notice'
          controller.stub(:get_projects).and_return([@project, @get_projects_notice])
          controller.stub(:get_ascii_text).and_return(@asciitext)
        end
        context 'when format html' do
          before do
            get :show, :encoding => 'ascii', :pmcdoc_id => @pmcdoc_id, :id => @id
          end
          
          it 'should set get_projects_notice as flash[:notice]' do
            flash[:notice].should eql(@get_doc_notice)  
          end
          
          it 'should render template' do
            response.should render_template('docs/show')
          end
        end

        context 'when format json' do
          before do
            get :show, :encoding => 'ascii', :format => 'json', :pmcdoc_id => @pmcdoc_id, :id => @id
          end
          
          it 'should render json' do
            hash = {
              :pmcdoc_id => @pmcdoc_id,
              :div_id => @id,
              :text => @asciitext
            }
            response.body.should eql(hash.to_json)
          end
        end
        
        context 'when format txt' do
          before do
            get :show, :encoding => 'ascii', :format => 'txt', :pmcdoc_id => @pmcdoc_id, :id => @id
          end
          
          it 'should render ascii text' do
            response.body.should eql(@asciitext)
          end
        end
      end
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
          before do
            controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
            get :show, :project_id => @project_id, :pmcdoc_id => @pmcdoc_id, :id => @id
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
      end
      
      context 'when get_project does not returns project' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
        end
        
        context 'when format html' do
          before do
            get :show, :project_id => @project_id, :pmcdoc_id => @pmcdoc_id, :id => @id
          end

          it '@doc should be nil' do
            assigns[:doc].should be_nil
          end  
          
          it 'should redirect to pmcdocs_path' do
            response.should redirect_to(pmcdocs_path)
          end
          
          it 'should set flash[:notice]' do
            flash[:notice].should eql(@get_project_notice)
          end
        end  
        
        context 'when format json' do
          before do
            get :show, :format => 'json', :project_id => @project_id, :pmcdoc_id => @pmcdoc_id, :id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
        
        context 'when format json' do
          before do
            get :show, :format => 'txt', :project_id => @project_id, :pmcdoc_id => @pmcdoc_id, :id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
      end
    end
    
    context 'when params[:sproject_id] exists' do
      before do
        @sproject_id = 'name of project'
        @sproject = FactoryGirl.create(:sproject, :name => @sproject_id)
        controller.stub(:get_sproject).and_return([@sproject, 'notice'])
        @doc = FactoryGirl.create(:doc)
        @get_annotations = 'get annotations'
        controller.stub(:get_annotations).and_return(@get_annotations)
        @get_doc_notice = 'get doc notice'
        controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
        @get_projects = 'get projects'
        controller.stub(:get_projects).and_return(@get_projects)
        get :show, :sproject_id => @sproject_id, :pmcdoc_id => 'pmcdoc_id', :id => 'id'
      end
      
      it 'should assign get_sproject as @sproject' do
        assigns[:sproject].should eql(@sproject)
      end
      
      it 'should assign get_doc as @doc' do
        assigns[:doc].should eql(@doc)
      end
      
      it 'should assign get_annotations as @annotations' do
        assigns[:annotations].should eql(@get_annotations)
      end
      
      it 'should assign get_projects as @projects' do
        assigns[:projects].should eql(@get_projects)
      end
      
      it 'should render template' do
        response.should render_template('docs/show')
      end      
    end
  end
  
  describe 'new' do
    before do
      @pmcdoc_id = 'pmcdoc id'  
    end
    
    context 'format html' do
      before do
        get :new, :pmcdoc_id => @pmcdoc_id
      end
      
      it '@doc should be new record' do
        assigns[:doc].new_record?.should be_true
      end
      
      it '@doc.sourceid should equal params[:pmcdoc_id]' do
        assigns[:doc].sourceid.should eql(@pmcdoc_id)
      end
      
      it '@doc.source should equal url and params[:pmcdoc_id]' do
        assigns[:doc].source.should eql('http://www.ncbi.nlm.nih.gov/pmc/' + @pmcdoc_id)
      end
    end
    
    context 'format html' do
      before do
        get :new, :format => 'json', :pmcdoc_id => @pmcdoc_id
      end
      
      it 'should render @doc as json' do
        response.body.should eql(assigns[:doc].to_json)
      end
    end
  end
  
  describe 'edit' do
    before do
      @doc = FactoryGirl.create(:doc)
      @notice = 'notice'
      controller.stub(:get_doc).and_return(@doc, @notice)
      get :edit, :pmcdoc_id => '', :id => ''
    end
    
    it '@doc should get_doc' do
      assigns[:doc].should eql(@doc)
    end
  end
  
  describe 'create' do
    before do
      @pmcdoc_id = 'pmcdoc id'
      @div_id = 1
      @section = 'section'
      @text = 'text'
      @project = FactoryGirl.create(:project)
    end  

    context 'when @doc exists' do
      context 'when format html' do
        before do
          post :create, :pmcdoc_id => @pmcdoc_id, :project_id => @project.id, :div_id => @div_id, :section => @section, :text => @text
        end
        
        it 'should redirect to doc_path' do
          response.should redirect_to(doc_path(assigns[:doc]))
        end
      end

      context 'when format json' do
        before do
          post :create, :format => 'json', :pmcdoc_id => @pmcdoc_id, :project_id => @project.id 
        end
        
        it 'should return blank header' do
          response.header.should be_blank
        end
      end
    end

    context 'when @doc does not exists' do
      context 'when format html' do
        before do
          Doc.any_instance.stub(:save).and_return(false)
          post :create, :pmcdoc_id => @pmcdoc_id, :project_id => @project.id, :div_id => 'div', :section => @section, :text => @text
        end

        it 'should redirect to doc_path' do
          response.should render_template('new')
        end
      end

      context 'when format json' do
        before do
          Doc.any_instance.stub(:save).and_return(false)
          post :create, :format => 'json', :pmcdoc_id => @pmcdoc_id, :project_id => @project.id, :div_id => 'div', :section => @section, :text => @text
        end

        it 'should return status 422' do
          response.status.should eql(422) 
        end
      end
    end
  end
  
  describe 'update' do
    before do
      @doc = FactoryGirl.create(:doc)
    end
        
    context 'update sucessfully' do
      context 'when format html' do
        before do
          post :update, :id => @doc.id, :pmcdoc_id => 'id', :doc => {:body => 'new body'}
        end
        
        it 'should redirect to doc_path' do
          response.should redirect_to(doc_path(assigns[:doc]))
        end
      end

      context 'when format json' do
        before do
          post :update, :format => 'json', :id => @doc.id, :pmcdoc_id => 'id', :doc => {:body => 'new body'}
        end
        
        it 'should return blank header' do
          response.header.should be_blank
        end
      end
    end
    
    context 'update unsucessfully' do
      before do
        Doc.any_instance.stub(:update_attributes).and_return(false)
      end
      
      context 'when format html' do
        before do
          post :update, :id => @doc.id, :pmcdoc_id => 'id', :doc => {:body => 'new body'}
        end
        
        it 'should render edit action' do
          response.should render_template('edit')
        end
      end
      
      context 'when format json' do
        before do
          post :update, :format => 'json', :id => @doc.id, :pmcdoc_id => 'id', :doc => {:body => 'new body'}
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
  end
  
  describe 'destroy' do
    before do
      @doc = FactoryGirl.create(:doc)  
    end
    
    context 'format html' do
      before do
        delete :destroy, :pmcdoc_id => 'id', :id => @doc.id
      end
      
      it 'should redirect to docs_url' do
        response.should redirect_to docs_url
      end
    end
    
    context 'format html' do
      before do
        delete :destroy, :format => 'json', :pmcdoc_id => 'id', :id => @doc.id
      end
      
      it 'should return blank header' do
        response.header.should be_blank
      end
    end
  end
end