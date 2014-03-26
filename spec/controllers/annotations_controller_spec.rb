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
  
  describe 'create' do
    before do
      @user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @user, :name => 'project name')
      controller.class.skip_before_filter :authenticate_user!
    end
    
    context 'when annotation_server or annotations exists' do
      before do
        controller.stub(:get_project).and_return(@project, 'notice')  
      end
      
      context 'and when doc exists' do
        context 'and when params annotation_server exists' do
          before do
            controller.stub(:get_annotations).and_return('get annotations')  
            controller.stub(:gen_annotations).and_return('gen annotations')  
            controller.stub(:save_annotations).and_return('save annotations') 
          end
          
          context 'when format is html' do
            context 'when doc.has_divs == true' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
                @doc.stub(:has_divs?).and_return(true)
                controller.stub(:get_doc).and_return(@doc, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :tax_ids => '1 2'
              end
              
              it 'should redirect to project_pmdoc_path' do
                response.should redirect_to(show_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial))
              end      
            end
            
            context 'when doc.sourcedb is free' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'FA', :sourceid => 1, :serial => 3) 
                controller.stub(:get_doc).and_return(@doc, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :tax_ids => '1 2'
              end
              
              it 'should redirect to project_pmdoc_path' do
                response.should redirect_to(project_doc_path(@project.name, @doc.id))
              end      
            end
          end
          
          context 'when format is json' do
            context 'when annotations exists' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
                controller.stub(:get_doc).and_return(@doc, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :annotations => {:id => 1}.to_json, :format => 'json', :tax_ids => '1 2'
              end
              
              it 'should return blank response header' do
                response.header.should be_blank
              end
            end

            context 'when annotations does not exists' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
                controller.stub(:get_doc).and_return(nil, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :format => 'json'
              end
              
              it 'should return status 422' do
                response.status.should eql(422)
              end
            end
          end
        end

        context 'and when params annotation_server does not exists' do
          before do
            controller.stub(:save_annotations).and_return('save annotations') 
          end
          
          context 'when doc.has_divs == true' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
              @doc.stub(:has_divs?).and_return(true)
              controller.stub(:get_doc).and_return(@doc, 'notice')  
              annotations = {:id => 1}.to_json  
              post :create, :project_id => 2, :annotations => annotations
            end
            
            it 'should redirect to project_pmdoc_path' do
              response.should redirect_to(show_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial))
            end      
          end
          
          context 'when doc.has_divs == false' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 1) 
              @doc.stub(:has_divs?).and_return(false)
              controller.stub(:get_doc).and_return(@doc, 'notice')
              annotations = {:id => 1}.to_json  
              post :create, :project_id => 2, :annotations => annotations
            end
            
            it 'should redirect to project_pmdoc_path' do
              response.should redirect_to(project_doc_path(@project.name, @doc.id))
            end      
          end
        end
      end      
      
      context 'and when doc does not exists' do
        before do
          controller.stub(:get_doc).and_return(nil, 'notice')  
          post :create, :project_id => 2, :annotation_server => 'annotation server'
        end
        
        it 'should redirect to project_path' do
          response.should redirect_to(project_path(@project.name))
        end      
      end      
    end

    context 'when annotation_server and annotations exists' do
      before do
        post :create, :project_id => 2
      end
      
      it 'should redirect to home_path' do
        should redirect_to(home_path)
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