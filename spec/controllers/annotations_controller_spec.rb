# encoding: utf-8
require 'spec_helper'

describe AnnotationsController do
  describe 'index' do
    context 'when project exists' do
      before do
        @user = FactoryGirl.create(:user)
        @project = FactoryGirl.create(:project, 
          :user => @user, 
          :name => 'test_name',
          :rdfwriter => '',
          :xmlwriter => '',
        )
        @project.docs << FactoryGirl.create(:doc)
        controller.stub(:get_project).and_return(@project)
        controller.stub(:get_docspec).and_return(nil)
        controller.stub(:get_doc).and_return('doc')
        @annotations = {
            :base_text => 'text val',
            :denotations => 'denotations val',
            :relations => 'relations val',
            :modifications => 'modifications val'
          }
        controller.stub(:get_annotations_for_json).and_return(@annotations)
      end
      
      context 'and when params pmdoc_id or pmc_doc_id exists' do
        
        context 'and when format is html' do
          before do
            get :index, :format => 'html', :project_id => @project.name, :pmdoc_id => 5
          end

          it 'should render html template' do
            response.should render_template('index')
          end
        end
        
        context 'and when format is json' do
          before do
            get :index, :format => 'json', :project_id => @project.name, :pmdoc_id => 5
          end

          it 'should render annotations as json' do
            response.body.should eql(@annotations.to_json)
          end
        end
        
        context 'and when format is ttl' do
          context 'and when project.rdfwriter is empty' do
            before do
              get :index, :format => 'ttl', :project_id => @project.name, :pmdoc_id => 5
            end
  
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end

          context 'and when project.rdfwriter is not empty' do
            before do            
              @project = FactoryGirl.create(:project, 
                :user => @user, 
                :name => 'test_name2',
                :rdfwriter => 'rdfwriter'
              )
              controller.stub(:get_project).and_return(@project)
              @get_conversion_text = 'rendered text'
              controller.stub(:get_conversion).and_return(@get_conversion_text)
              get :index, :format => 'ttl', :project_id => @project.name, :pmdoc_id => 5
            end

            it 'should return get_conversion text' do
              response.body.should eql(@get_conversion_text)
            end
          end
        end
        
        context 'and when format is xml' do
          context 'and when project.rdfwriter is empty' do
            before do
              get :index, :format => 'xml', :project_id => @project.name, :pmdoc_id => 5
            end
  
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end

          context 'and when project.rdfwriter is not empty' do
            before do
              @project = FactoryGirl.create(:project, 
                :user => @user, 
                :name => 'test_name3',
                :xmlwriter => 'xmlwriter'
              )
              controller.stub(:get_project).and_return(@project)
              @get_conversion_text = 'rendered text'
              controller.stub(:get_conversion).and_return(@get_conversion_text)
              get :index, :format => 'xml', :project_id => @project.name, :pmdoc_id => 5
            end
  
            it 'should return get_conversion text' do
              response.body.should eql(@get_conversion_text)
            end
          end
        end
      end

      context 'and when params pmdoc_id nor pmc_doc_id does not exists' do
        context 'and when anncollection exists' do
          context 'when params[:delay] present' do
            before do
               Project.any_instance.stub(:anncollection).and_return(
                [{
                  :source_db => 'source_db',
                  :source_id => 'source_id',
                  :division_id => 1,
                  :section => 'section',
               }])
               @refrerer = root_path
              request.env["HTTP_REFERER"] = @refrerer
              get :index, :delay => true, :project_id => @project.name
            end
            
            it 'should redirect to back' do
              response.should redirect_to(@refrerer)
            end
            
            after do
              # delete ZIP file
              File.unlink(@project.annotations_zip_path)
            end  
          end
          
          context 'when format is json' do
            before do
               Project.any_instance.stub(:anncollection).and_return(
                [{
                  :source_db => 'source_db',
                  :source_id => 'source_id',
                  :division_id => 1,
                  :section => 'section',
               }])
              get :index, :format => 'json', :project_id => @project.name
            end
            
            it 'should returns zip' do
              response.header['Content-Type'].should eql('application/zip')
            end
          end
  
          context 'when format is ttl' do
            before do
              controller.stub(:get_conversion).and_return(
              'line1
              line2
              line3
              line4
              line5
              line6
              line7
              line8
              line9
              ')
              get :index, :format => 'ttl', :project_id => @project.name
            end
            
            it 'should returns x-turtle' do
              response.header['Content-Type'].should eql('application/x-turtle; charset=utf-8')
            end
          end
        end

        context 'and when anncollection does not exists' do
          before do
            Project.any_instance.stub(:anncollection).and_return([])            
          end
          
          context 'and whern format html' do
            before do
              get :index, :format => 'html', :project_id => @project.name
            end
            
            it 'should render template' do
              response.should render_template('index')
            end
          end
          
          context 'and whern format json' do
            before do
              get :index, :format => 'json', :project_id => @project.name
            end
            
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end
          
          context 'and whern format ttl' do
            before do
              get :index, :format => 'ttl', :project_id => @project.name
            end
            
            it 'should return error 422' do
              response.status.should eql(422)
            end
          end
        end
      end
    end
  end
  
  describe 'create with minimal stubs' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @annotation_server = 'http://pubdictionaries.dbcls.jp/dictionaries/EntrezGene%20-%20Homo%20Sapiens/text_annotation?matching_method=approximate&max_tokens=6&min_tokens=1&threshold=0.6&top_n=0'
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @project = FactoryGirl.create(:project, name: 'project name', user: @current_user)
      @sourceid = '12345'
      @body = 'doc body'
      @referer_path = docs_path
      request.env["HTTP_REFERER"] = @referer_path
      controller.stub(:get_project).and_return(@project, 'notice') 
      @get_annotations = 'get annotations'
      controller.stub(:get_annotations).and_return(@get_annotations)  
      @gen_annotations = 'gen annotations'
      controller.stub(:gen_annotations).and_return(@gen_annotations)
      @save_annotations = 'save annotations'
      controller.stub(:save_annotations) do |annotations|
        @annotations = annotations
      end
      @doc = FactoryGirl.create(:doc, sourcedb: 'PubMed', sourceid: @sourceid, serial: 0, body: @body)
    end
    
    context 'when params[:annotation_server] or params[:annotations]  present' do
      context 'when project present' do
        context 'when params[:doc_id].present? /projects/:project_id/docs/:doc_id/annotations?annotation_server=...' do
          before do
            post :create, project_id: @project.name, doc_id: @doc.id, annotation_server: @annotation_server 
          end  
          
          it 'should redirect_to :back' do
            response.should redirect_to @referer_path
          end
        end
        
        context 'when params[doc_id] blank' do
          before do
            controller.stub(:get_docspec).and_return(nil)
            controller.stub(:get_doc).and_return(@doc)
            post :create, project_id: @project.name, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, annotation_server: @annotation_server 
          end  
          
          it 'should redirect_to :back' do
            response.should redirect_to @referer_path
          end
        end

        context 'when doc present' do
          context 'when params[:annotation_server].present?' do
            before do
              controller.stub(:get_doc).and_return(@doc)
              post :create, project_id: @project.name, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, annotation_server: @annotation_server 
            end
            
            it 'annotations should generated by gen_annotations' do
              @annotations.should eql @gen_annotations
            end
          end

          context 'when params[:annotation_server].blank' do
            before do
              controller.stub(:get_doc).and_return(@doc)
              @params_annotations = 'params annotations'
              JSON.stub(:parse).and_return(@params_annotations)
              post :create, project_id: @project.name, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, annotations: @params_annotations
            end
            
            it 'annotations should generated by JSON.parse params[:annotations]' do
              @annotations.should eql @params_annotations
            end
          end
        end

        context 'when doc blank' do
          before do
            controller.stub(:get_doc).and_return(nil)
            post :create, project_id: @project.name, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, annotation_server: @annotation_server 
          end
          
          it 'shoud set flash notice' do
            flash[:notice].should eql I18n.t('controllers.annotations.create.does_not_include', :project_id => @project.name, :sourceid => @doc.sourceid)
          end
        end
      end

      describe 'response' do
        context 'when format html' do
          context 'when doc and project present' do
            before do
              Doc.stub(:find).and_return(@doc)
              post :create, project_id: 'project', doc_id: 1, annotation_server: 'server'
            end
              
            it 'should redirect_to :back' do
              response.should redirect_to @referer_path
            end        
          end
          
          context 'when project present' do
            before do
              Doc.stub(:find).and_return(nil)
              post :create, project_id: 'project', doc_id: 1, annotation_server: 'server'
            end
              
            it 'should redirect_to :back' do
              response.should redirect_to project_path(@project.name)
            end        
          end
          
          context 'when doc project blank' do
            before do
              controller.stub(:get_project).and_return(nil, 'notice') 
              Doc.stub(:find).and_return(nil)
              post :create, project_id: 'project', doc_id: 1, annotation_server: 'server'
            end
              
            it 'should redirect_to :back' do
              response.should redirect_to home_path
            end        
          end
        end

        context 'when format json' do
          context 'when annotations exists' do
            before do
              post :create, project_id: 'project', doc_id: 1, annotation_server: 'server', format: :json, annotations: {:id => 1}.to_json
            end
            
            it 'should return blank response header' do
              response.header.should be_blank
            end
          end

          context 'when annotations does not exists' do
            before do
              post :create, project_id: 'project', doc_id: 1, format: :json
            end
            
            it 'should return status 422' do
              response.status.should eql(422)
            end
          end
        end
       end
    end
    
    context 'when params[:annotation_server] or params[:annotations] blank' do
      before do
        post :create, project_id: 'project', doc_id: 1
      end

      it 'shoud set flash notice' do
        flash[:notice].should eql I18n.t('controllers.annotations.create.no_annotation') 
      end
    end
  end
  
  describe 'set_access_control_headers' do
    context 'when HTTP_ORIGIN includes allowed_origins' do
      before do
        @controller = AnnotationsController.new
        @http_origin = 'http://bionlp.dbcls.jp'
        @controller.stub(:request).and_return(double(:env => {'HTTP_ORIGIN' => 'http://bionlp.dbcls.jp'}))
        @headers = Hash.new
        @controller.stub(:headers).and_return(@headers)
        @controller.instance_eval{ set_access_control_headers }
      end
      
      it 'shoule set headers Access-Control-Allow-Origin' do
        @headers['Access-Control-Allow-Origin'].should eql(@http_origin)
      end
      
      it 'shoule set headers Access-Control-Expose-Headers' do
        @headers['Access-Control-Expose-Headers'].should eql('ETag')
      end
      
      it 'shoule set headers Access-Control-Allow-Methods' do
        @headers['Access-Control-Allow-Methods'].should eql('GET, POST, OPTIONS')
      end
      
      it 'shoule set headers Access-Control-Allow-Headers' do
        @headers['Access-Control-Allow-Headers'].should eql('Authorization, X-Requested-With')
      end
      
      it 'shoule set headers Access-Control-Allow-Credentials' do
        @headers['Access-Control-Allow-Credentials'].should eql('true')
      end
      
      it 'shoule set headers Access-Control-Max-Age' do
        @headers['Access-Control-Max-Age'].should eql('1728000')
      end
    end
  end
  
  describe 'destroy_all' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @project = FactoryGirl.create(:project)
      @another_project = FactoryGirl.create(:project)
      controller.stub(:get_project).and_return([@project])
      controller.stub(:get_docspec).and_return(nil)
      
      @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => '123')
      controller.stub(:get_doc).and_return([@doc])
      @denotation_1 = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @denotation_2 = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @denotation_3 = FactoryGirl.create(:denotation, :project => @another_project, :doc => @doc)
      @referer_path = root_path
      request.env["HTTP_REFERER"] = @referer_path
    end
    
    context 'when annotations_destroy_all_project_sourcedb_sourceid_docs' do
      before do
        post :destroy_all, :project_id => @project.name, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid 
      end    
      
      it 'should destroy doc.denotation belongs to project' do
        Denotation.find_by_id(@denotation_1.id).should be_nil
        Denotation.find_by_id(@denotation_2.id).should be_nil
      end
      
      it 'should not destroy doc.denotation not belongs to project' do
        Denotation.find_by_id(@denotation_3.id).should be_present
      end
      
      it 'should redirect_to back' do
        response.should redirect_to @referer_path
      end
    end
    
    context 'when annotations_project_sourcedb_sourceid_divs_docs' do
      before do
        post :destroy_all, :project_id => @project.name, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid 
      end    
      
      it 'should destroy doc.denotation belongs to project' do
        Denotation.find_by_id(@denotation_1.id).should be_nil
        Denotation.find_by_id(@denotation_2.id).should be_nil
      end
      
      it 'should not destroy doc.denotation not belongs to project' do
        Denotation.find_by_id(@denotation_3.id).should be_present
      end
      
      it 'should redirect_to back' do
        response.should redirect_to @referer_path
      end
    end
      
    describe 'transaction cause error' do
      before do
        ActiveRecord::Relation.any_instance.stub(:destroy_all).and_raise('ERROR')
        post :destroy_all, :project_id => @project.name, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid 
      end
      
      it 'should set flash[:notice]' do
        flash[:notice].should be_present
      end
    end
  end
end 