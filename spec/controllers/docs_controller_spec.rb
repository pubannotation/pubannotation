# encoding: utf-8
require 'spec_helper'

describe DocsController do
  describe 'index' do
    before do
      @doc = FactoryGirl.create(:doc, :sourceid => 'sourceid', :serial => 1, :section => 'section')
    end
    
    context 'when params[:project_id] exists' do
      before do
        @project = FactoryGirl.create(:project)
        @project_id = 'project id'
        @get_project_notice = 'get project notice'
      end
      
      context 'when get_project returns project' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
          get :index, :project_id => @project_id
        end
        
        it 'should render template' do
          response.should render_template('index')
        end
      end

      context 'when get_project does not returns project' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
        end
        
        context 'when format html' do
          before do
            get :index, :project_id => @project_id
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
          
          it 'set get_project notice as flash[:notice]' do
            flash[:notice].should eql(@get_project_notice)
          end
        end
        
        context 'when format json' do
          before do
            get :index, :format => 'json', :project_id => @project_id
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end
        
        context 'when format text' do
          before do
            get :index, :format => 'txt', :project_id => @project_id
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end
      end
    end

    context 'when params[:project_id] does not exists' do
      context 'when format html' do
        before do
          get :index
        end
        
        it 'should render template' do
          response.should render_template('index')
        end
      end

      context 'when format json' do
        before do
          get :index, :format => 'json'
        end
        
        it 'should render @docs as json' do
          response.body.should eql(assigns[:docs].to_json)
        end
      end

      context 'when format text' do
        before do
          get :index, :format => 'txt'
        end
        
        it 'should return zpi' do
          response.content_type.should eql("application/zip")
        end
      end
    end
  end
  
  describe 'show' do
    before do
      @doc = FactoryGirl.create(:doc)  
    end
    
    context 'when format html' do
      before do
        get :show, :id => @doc.id
      end
      
      it 'should render template' do
        response.should render_template('show')
      end
    end
    
    context 'when format json' do
      before do
        get :show, :format => 'json', :id => @doc.id
      end
      
      it 'should render @doc as json' do
        response.body.should eql(@doc.to_json)
      end
    end
  end
  
  describe 'new' do
    context 'when format html' do
      before do
        get :new
      end
      
      it 'should buid new doc' do
        assigns[:doc].new_record?.should be_true
      end
      
      it 'should render template' do
        response.should render_template('new')
      end
    end
    
    context 'when format json' do
      before do
        get :new, :format => 'json'
      end
      
      it 'should render @doc as json' do
        response.body.should eql(assigns[:doc].to_json)
      end
    end
  end
  
  describe 'edit' do
    before do
      @doc = FactoryGirl.create(:doc)
      get :edit, :id => @doc.id
    end
    
    it 'should render template' do
      response.should render_template('edit')
    end
    
    it 'find Doc correctly' do
      assigns[:doc].should eql(@doc)
    end
  end
  
  describe 'create' do
    context 'when save successfully' do
      context 'when format html' do
        before do
          post :create
        end
        
        it 'should redirect to doc_path' do
          response.should redirect_to(doc_path(assigns[:doc]))
        end
      end

      context 'when format json' do
        before do
          post :create, :format => 'json'
        end
        
        it 'should render @doc as json' do
          response.body.should eql(assigns[:doc].to_json)
        end
        
        it 'should return status created' do
          response.status.should eql(201)
        end
        
        it 'should return doc_path as location' do
          response.location.should eql("http://test.host#{doc_path(assigns[:doc])}")
        end
      end
    end

    context 'when save unsuccessfully' do
      context 'when format html' do
        before do
          Doc.any_instance.stub(:save).and_return(false)
          post :create
        end
        
        it 'should render new action' do
          response.should render_template('new')
        end
      end

      context 'when format json' do
        before do
          Doc.any_instance.stub(:save).and_return(false)
          post :create, :format => 'json'
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
    
    context 'when update successfully' do
      before do
        @params_doc = {:body => 'body'}
      end
      
      context 'when format html' do
        before do
          post :update, :id => @doc.id, :doc => @params_doc
        end
        
        it 'should redirect to doc_path' do
          response.should redirect_to(doc_path(@doc))
        end
      end

      context 'when format json' do
        before do
          post :update, :format => 'json', :id => @doc.id, :doc => @params_doc
        end
        
        it 'should return blank header' do
          response.header.should be_blank
        end
      end
    end
    
    context 'when update unsuccessfully' do
      before do
        @params_doc = {:body => 'body'}
        Doc.any_instance.stub(:update_attributes).and_return(false)
      end
      
      context 'when format html' do
        before do
          post :update, :id => @doc.id, :doc => @params_doc
        end
        
        it 'should render edit action' do
          response.should render_template('edit')
        end
      end

      context 'when format json' do
        before do
          post :update, :format => 'json', :id => @doc.id, :doc => @params_doc
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
        delete :destroy, :id => @doc.id
      end
      
      it 'should redirect to docs_url' do
        response.should redirect_to(docs_url)
      end
    end

    context 'format json' do
      before do
        delete :destroy, :format => 'json', :id => @doc.id
      end
      
      it 'should return blank header' do
        response.header.should be_blank
      end
    end
  end
end