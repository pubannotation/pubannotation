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
            :text => 'text val',
            :denotations => 'denotations val',
            :instances => 'instances val',
            :relations => 'relations val',
            :modifications => 'modifications val'
          }
        controller.stub(:get_annotations).and_return(@annotations)
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
          context 'when format is json' do
            before do
              controller.stub(:get_annotations).and_return(
              {
                :source_db => 'source_db',
                :source_id => 'source_id',
                :division_id => 1,
                :section => 'section',
               })
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
            controller.stub(:get_annotations).and_return('')
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
            context 'when doc.sourcedb == PubMed' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 1) 
                controller.stub(:get_doc).and_return(@doc, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :tax_ids => '1 2'
              end
              
              it 'should redirect to project_pmdoc_path' do
                response.should redirect_to(project_pmdoc_path(@project.name, @doc.sourceid))
              end      
            end
            
            context 'when doc.sourcedb == PubMed' do
              before do
                @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
                controller.stub(:get_doc).and_return(@doc, 'notice')  
                post :create, :project_id => 2, :annotation_server => 'annotation server', :tax_ids => '1 2'
              end
              
              it 'should redirect to project_pmdoc_path' do
                response.should redirect_to(project_pmcdoc_div_path(@project.name, @doc.sourceid, @doc.serial))
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
          
          context 'when doc.sourcedb == PubMed' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 1) 
              controller.stub(:get_doc).and_return(@doc, 'notice')
              annotations = {:id => 1}.to_json  
              post :create, :project_id => 2, :annotations => annotations
            end
            
            it 'should redirect to project_pmdoc_path' do
              response.should redirect_to(project_pmdoc_path(@project.name, @doc.sourceid))
            end      
          end
          
          context 'when doc.sourcedb == PubMed' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1, :serial => 3) 
              controller.stub(:get_doc).and_return(@doc, 'notice')  
              annotations = {:id => 1}.to_json  
              post :create, :project_id => 2, :annotations => annotations
            end
            
            it 'should redirect to project_pmdoc_path' do
              response.should redirect_to(project_pmcdoc_div_path(@project.name, @doc.sourceid, @doc.serial))
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
    # destroy_all_project_pmdoc_annotations
    #POST   /projects/:project_id/pmdocs/:pmdoc_id/annotations/destroy_all(.:format)
    before do
      controller.class.skip_before_filter :authenticate_user!
      # project
      @project = FactoryGirl.create(:project)
      # associate projects
      @associate_project_annotations_0 = FactoryGirl.create(:project)
      @associate_project_annotations_3 = FactoryGirl.create(:project)
      controller.stub(:get_project).and_return([@associate_project_annotations_3, nil])
      @another_project = FactoryGirl.create(:project)
      @referer_path = root_path
      request.env["HTTP_REFERER"] = @referer_path
    end

    context 'when pmdoc' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 12345, :serial => 0) 
        controller.stub(:get_doc).and_return([@doc, nil])
        # add denotations to associate_projects
        @doc_denotatons_count = 3
        @doc_denotasions_related_model_count = 2
        @doc_denotatons_count.times do
          denotation = FactoryGirl.create(:denotation, :project => @associate_project_annotations_3, :doc => @doc)
          @doc_denotasions_related_model_count.times do
            FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @associate_project_annotations_3)
            FactoryGirl.create(:instance, :obj => denotation, :project => @associate_project_annotations_3)
          end
        end
        @associate_project_annotations_0.reload
        @associate_project_annotations_3.reload
        # add associate_projects to project
        @project.associate_projects << @associate_project_annotations_0
        @project.associate_projects << @associate_project_annotations_3
        # another_project
        denotation = FactoryGirl.create(:denotation, :project => @another_project, :doc => @doc)
        FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @another_project)
        FactoryGirl.create(:instance, :obj => denotation, :project => @another_project)
        # another_doc
        @another_doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 123456, :serial => 0) 
        denotation = FactoryGirl.create(:denotation, :project => @another_project, :doc => @another_doc)
        FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @another_project)
        FactoryGirl.create(:instance, :obj => denotation, :project => @another_project)
      end
      
      it 'denotations are present' do
        Denotation.all.size.should eql(@doc_denotatons_count + 2)
      end
      
      it 'relations are present' do
        Relation.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
      end
      
      it 'relations are present' do
        Instance.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
      end
      
      it 'denotations are present' do
        @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).size.should eql(@doc_denotatons_count)
      end
      
      it 'denotation.instances, subrels, objrels should present' do
        @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).each do |denotation|
          denotation.instances.should be_present
          denotation.subrels.should be_present 
          denotation.objrels.should be_present 
        end
      end
      
      it 'should increment project.denotations_count when add assciate projects' do
        @associate_project_annotations_3.denotations_count.should eql(@doc_denotatons_count)
      end
      
      it 'project.denotations_count should equal sum of assciate projects denotations_count' do
        @project.denotations_count.should eql(0)
        @project.reload
        @project.denotations_count.should eql(@associate_project_annotations_3.denotations_count)
      end

      describe 'post' do
        before do
          post :destroy_all, :project_id => @associate_project_annotations_3.name, :pmdoc_id => @doc.sourceid
        end
        
        it 'doc.denotations should be blank' do
          @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).should be_blank
        end
        
        it 'relation count should reduced ' do
          Relation.all.size.should eql(2)
        end
        
        it 'relation count should reduced ' do
          Instance.all.size.should eql(2)
        end
        
        it 'denotation.instances, subrels, objrels should present' do
          Denotation.all.size.should eql(2)
        end
        
        it 'should redirect_to referer path' do
          response.should redirect_to(@referer_path)
        end
        
        it 'should reset project.denotaions_count' do
          @project.reload
          @project.denotations_count.should eql(0)
        end
      
        it 'should reset associate project.denotaions_count' do
          @associate_project_annotations_0.reload
          @associate_project_annotations_0.denotations_count.should eql(0)
        end
      
        it 'should reset associate project.denotaions_count' do
          @associate_project_annotations_3.reload
          @associate_project_annotations_3.denotations_count.should eql(0)
        end
      end
      
      describe 'transaction cause error' do
        before do
          ActiveRecord::Relation.any_instance.stub(:destroy_all).and_raise('ERROR')
          #ActiveRecord::Relation.stub(:destroy_all).and_raise('ERROR')
          post :destroy_all, :project_id => @project.name, :pmdoc_id => @doc.sourceid
        end
        
        it 'should set flash[:notice]' do
          flash[:notice].should be_present
        end
        
        it 'denotations are not destroied' do
          Denotation.all.size.should eql(@doc_denotatons_count + 2)
        end
        
        it 'relations are not destroied' do
          Relation.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
        end
        
        it 'relations are not destroied' do
          Instance.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
        end        
      end
    end

    context 'when pmcdoc' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 12345, :serial => 0) 
        controller.stub(:get_doc).and_return([@doc, nil])
        @doc_denotatons_count = 3
        @doc_denotasions_related_model_count = 2
        @doc_denotatons_count.times do
          denotation = FactoryGirl.create(:denotation, :project => @associate_project_annotations_3, :doc => @doc)
          @doc_denotasions_related_model_count.times do
            FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @associate_project_annotations_3)
            FactoryGirl.create(:instance, :obj => denotation, :project => @associate_project_annotations_3)
          end
        end
        @associate_project_annotations_0.reload
        @associate_project_annotations_3.reload
        # add associate_projects to project
        @project.associate_projects << @associate_project_annotations_0
        @project.associate_projects << @associate_project_annotations_3
        # another_project
        denotation = FactoryGirl.create(:denotation, :project => @another_project, :doc => @doc)
        FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @another_project)
        FactoryGirl.create(:instance, :obj => denotation, :project => @another_project)
        # another_doc
        @another_doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 123456, :serial => 0) 
        denotation = FactoryGirl.create(:denotation, :project => @another_project, :doc => @another_doc)
        FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => denotation.class.to_s, :obj => denotation, :project => @another_project)
        FactoryGirl.create(:instance, :obj => denotation, :project => @another_project)
      end
      
      it 'denotations are present' do
        Denotation.all.size.should eql(@doc_denotatons_count + 2)
      end
      
      it 'relations are present' do
        Relation.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
      end
      
      it 'relations are present' do
        Instance.all.size.should eql(@doc_denotatons_count * @doc_denotasions_related_model_count + 2)
      end
      
      it 'denotations are present' do
        @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).size.should eql(@doc_denotatons_count)
      end
      
      it 'denotation.instances, subrels, objrels should present' do
        @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).each do |denotation|
          denotation.instances.should be_present
          denotation.subrels.should be_present 
          denotation.objrels.should be_present 
        end
      end
      
      it 'should increment project.denotations_count when add assciate projects' do
        @associate_project_annotations_3.denotations_count.should eql(@doc_denotatons_count)
      end
      
      it 'project.denotations_count should equal sum of assciate projects denotations_count' do
        @project.denotations_count.should eql(0)
        @project.reload
        @project.denotations_count.should eql(@associate_project_annotations_3.denotations_count)
      end
                  
      describe 'post' do
        before do
          post :destroy_all, :project_id => @associate_project_annotations_3.name, :div_id => 0, :pmcdoc_id => @doc.sourceid
        end
        
        it 'doc.denotations should be blank' do
          @doc.denotations.where("project_id = ?", @associate_project_annotations_3.id).should be_blank
        end
        
        it 'relation count should reduced ' do
          Relation.all.size.should eql(2)
        end
        
        it 'relation count should reduced ' do
          Instance.all.size.should eql(2)
        end
        
        it 'denotation.instances, subrels, objrels should present' do
          Denotation.all.size.should eql(2)
        end
        
        it 'should redirect_to referer path' do
          response.should redirect_to(@referer_path)
        end
          
        it 'should reset project.denotaions_count' do
          @project.reload
          @project.denotations_count.should eql(0)
        end
      
        it 'should reset associate project.denotaions_count' do
          @associate_project_annotations_0.reload
          @associate_project_annotations_0.denotations_count.should eql(0)
        end
      
        it 'should reset associate project.denotaions_count' do
          @associate_project_annotations_3.reload
          @associate_project_annotations_3.denotations_count.should eql(0)
        end
      end
    end
  end
end 