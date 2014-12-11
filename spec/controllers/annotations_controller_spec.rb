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
              @project.stub_chain(:delay, :save_annotation_zip).and_return(nil)
            end
            
            it 'should call create notice method' do
              @project.notices.should_receive(:create).with({method: 'start_delay_save_annotation_zip'})
              get :index, :delay => true, :project_id => @project.name
            end

            it 'should create notice' do
              expect{ get :index, :delay => true, :project_id => @project.name }.to change{ Notice.count }.from(0).to(1)
            end
            
            it 'should call delay.save_annotation_zip' do
              @project.should_receive(:delay)
              get :index, :delay => true, :project_id => @project.name
            end
            
            it 'should redirect to back' do
              get :index, :delay => true, :project_id => @project.name
              response.should redirect_to(@refrerer)
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
              controller.stub(:get_annotations_for_json).and_return({val: 'val'})
              controller.stub(:get_doc_info).and_return('')
              get :index, :format => 'json', :project_id => @project.name
              get :index, :format => 'json', :project_id => @project.name
            end
            
            it 'should returns zip' do
              response.header['Content-Type'].should eql('application/zip')
            end
          end
  
          context 'when format is ttl' do
            before do
              @project.docs << FactoryGirl.create(:doc)
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
            end
            
            it 'should returns x-turtle' do
              @get_conversion = 'get 
              @
              conversion'
              controller.stub(:get_conversion).and_return(@get_conversion)
              controller.should_receive(:get_conversion).twice
              get :index, :format => 'ttl', :project_id => @project.name
              response.body
            end

            it 'should returns x-turtle' do
              get :index, :format => 'ttl', :project_id => @project.name
              response.header['Content-Type'].should eql('application/x-turtle; charset=utf-8')
            end
          end
        end

        context 'and when anncollection does not exists' do
          before do
            Project.any_instance.stub(:docs).and_return([])            
          end
          
          context 'and whern format html' do
            before do
              get :index, :format => 'html', :project_id => @project.name
            end
            
            it 'should render template' do
              response.should render_template('index')
            end
          end
          
          context 'and when format json' do
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
  
  describe 'annotations_index' do
    before do
      controller.stub(:get_docspec).and_return(nil)
    end
    
    context 'when @doc present' do
      before do
        @doc = FactoryGirl.create(:doc)
        @project_denotations = 'project_denotations'
        @doc.stub(:project_denotations).and_return(@project_denotations)
        controller.stub(:get_doc).and_return([@doc, nil])
        @get_annotations_for_json = {:root => 'get_annotations_for_json'}
        controller.stub(:get_annotations_for_json).and_return(@get_annotations_for_json)
      end
      
      context 'when format html' do
        before do
          get :annotations_index, :id => @doc.id   
        end
        
        it 'should assign @doc.project_denotatios as @denotations' do
          assigns[:denotations].should eql(@project_denotations)
        end
        
        it 'should render template' do
          response.should render_template('annotations_index')
        end
      end
      
      context 'when format json' do
        before do
          get :annotations_index, :id => @doc.id, :format => 'json'   
        end
        
        it 'should render template' do
          response.body.should eql(@get_annotations_for_json.to_json)
        end
      end
    end
  end

  describe 'annotations' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :name => 'project_name')
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '123456')
      @get_doc_notice = 'notice'
      controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
      @get_project_notice = 'project notice'
    end
    
    context 'when params[:project_id] present' do
      context 'when @project present' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
          @project_denotations = 'project denotations'
          controller.stub(:get_project_denotations).and_return(@project_denotations)
          get :annotations, :project_id => @project.name, :id => @doc.id, :begin => 1, :end => 10
        end

        it 'should assign @doc' do
          assigns[:doc].should eql(@doc)
        end
       
        it 'should assigns project_denotatios' do
          assigns[:project_denotations].should eql(@project_denotations)
        end

        it 'should assing get_doc notice as flash[:notice]' do
          flash[:notice].should eql @get_doc_notice
        end
      end

      context 'when @project blank' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
          get :annotations, :project_id => @project.name, :id => @doc.id, :begin => 1, :end => 10
        end

        it 'should not assign @doc' do
          assigns[:doc].should be_nil
        end

        it 'should assing get_project notice as flash[:notice]' do
          flash[:notice].should eql @get_project_notice
        end
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        controller.stub(:get_project_denotations) do |projects, doc, params|
          projects
        end
        @project_user = FactoryGirl.create(:user)
        @project_1 = FactoryGirl.create(:project, user: @project_user)
        @project_2 = FactoryGirl.create(:project, user: @project_user)
        @project_3 = FactoryGirl.create(:project, user: @project_user)
        controller.stub(:get_annotations_for_json).and_return({denotations: nil, relations: nil, modifications: nil})
      end

      context 'when params[:projects] present' do
        context 'when some projects present' do
          before do
            @params_projects = [@project_1, @project_2]
            Project.stub(:name_in).and_return(@params_projects)
            get :annotations, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, :begin => 1, :end => 10, projects: @params_projects.collect{|project| project.name}.join(',')
          end

          # check once in the context params[:project_id] is blank
          it 'should assign @doc' do
            assigns[:doc].should eql(@doc)
          end

          # check once in the context params[:project_id] is blank
          it 'should assing get_doc notice as flash[:notice]' do
            flash[:notice].should eql @get_doc_notice
          end

          it 'should assign @project_denotations only name_in params[:projects]' do
            assigns[:project_denotations].should =~ @params_projects
          end
        end

        context 'when a project present' do
          before do
            @params_projects = [@project_1]
            Project.stub(:name_in).and_return(@params_projects)
            get :annotations, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, :begin => 1, :end => 10, projects: @params_projects.collect{|project| project.name}.join(',')
          end


          it 'should assign @project_denotations only name_in params[:projects]' do
            assigns[:project_denotations].should =~ @params_projects
          end
        end
      end

      context 'when params[:projects] blank' do
        before do
          @doc_projects = [@project_1, @project_2, @project_3]
          @doc.stub(:projects).and_return(@doc_projects)
          get :annotations, :id => @doc.id, :begin => 1, :end => 10
        end

        it 'should assign @project_denotations @doc.projects' do
          assigns[:project_denotations].should =~ @doc_projects
        end
      end
    end

    context 'when @doc present' do
      context 'when @spans present' do
        before do
          @spans = 'spans' 
          @prev_text = 'prevx text'
          @next_text = 'next text'
          Doc.any_instance.stub(:spans).and_return([@spans, @prev_text, @next_text])
          @begin = 1
          @denotations = [{span: {begin: 0, end: 5}}]
          @project_denotations = 'project denotations'
          controller.stub(:get_project_denotations).and_return(@project_denotations)
          @tracks = [{denotations: [{span: {begin: 1, end: 8}}]}]
        end

        before do
          @annotations ={
            :text => "text",
            :tracks => @tracks,
            :denotations => @denotations,
            :instances => "instances",
            :relations => "relations",
            :modifications => "modifications"
          }
          controller.stub(:get_annotations_for_json).and_return(@annotations)
          get :annotations, :id => @doc.id, :begin => @begin, :end => 10, format: 'json'
          @json = JSON.parse(response.body)
        end
       
        it 'set text to get_annotations_for_json text' do
          @json['text'].should eql(@annotations[:text])
        end
       
        it 'should assigns project_denotatios' do
          assigns[:project_denotations].should eql(@project_denotations)
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

        it 'should assign @relations' do
          assigns[:relations].should eql(@annotations[:relations])
        end

        it 'should assign @modifications' do
          assigns[:modifications].should eql(@annotations[:modifications])
        end

        it 'should assign get_annotations_for_json tracks as annotations[:tracks]' do
          @json['tracks'].should eql(JSON.parse(@annotations[:tracks].to_json))
        end

        it 'should assign annotations[:denotations] as @denotations' do
          assigns[:denotations].should eql [{"span" => {"begin" => 0, "end" => 5}}]
        end
      end
    end
  end


  describe 'create' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @current_user = FactoryGirl.create(:user)
      # current_user_stub(@current_user)
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, name: 'project name', user: @current_user)
    end

    context 'when project present' do
      before do
        controller.stub(:get_project).and_return(@project)
      end

      context' when divs present' do
        before do
          controller.stub(:get_docspec).and_return(['sourcedb', 'sourceid', 'divno'])
          controller.stub(:get_doc).and_return([@doc])
          @project.docs << @doc
        end

        context 'when params[:annotaitons] present' do
          before do
            @annotations = {'key' => 'value'}
          end

          context 'when format == json' do
            it 'should execute store_annotations by delayed_job' do
              Shared.should_receive(:delay)  
              Shared.should_receive(:store_annotations).with(@annotations.symbolize_keys, @project, [@doc], {mode: nil, delayed: true})  
              Shared.stub(:delay).and_return(Shared)
              post :create, project_id: @project.id, annotations: @annotations, format: 'json'
            end

            it 'should create notice' do
              Shared.stub_chain(:delay, :store_annotations).and_return(nil)
              expect{ post :create, project_id: @project.id, annotations: @annotations, format: 'json' }.to change{ Notice.count }.from(0).to(1)
            end

            it 'should call create notices method' do
              Shared.stub_chain(:delay, :store_annotations).and_return(nil)
              @project.notices.should_receive(:create)
              post :create, project_id: @project.id, annotations: @annotations, format: 'json'
            end

            it 'should return status created , fits delayed_job message' do
              Shared.stub_chain(:delay, :store_annotations).and_return(nil)
              post :create, project_id: @project.id, annotations: @annotations, format: 'json'
              response.body.should eql({'status' => 'created', 'fits' => I18n.t('controllers.annotations.create.delayed_job')}.to_json)
            end
          end

          context 'when format == html' do
            before do
              @referer_path = docs_path
              request.env["HTTP_REFERER"] = @referer_path
            end

            it 'should execute store_annotations without delayed_job with params[:annotaitons] symbolize_keys' do
              Shared.should_not_receive(:delay)  
              Shared.should_receive(:store_annotations).with(@annotations.symbolize_keys, @project, [@doc], {mode: nil})  
              post :create, project_id: @project.id, annotations: @annotations, format: 'html'
            end
          end
        end

        context 'when params[:annotaitons] blank and params[:text] present' do
          before do
            @params_text ='text'
            @params_denotations = 'denotations'
            @params_relations = 'relations'
            @params_modifications = 'modifications'
          end

          context 'when format == json' do
            it 'should execute store_annotations by delayed_job with annotaitons generate by params text, denotations, relations and modifications' do
              Shared.should_receive(:delay)  
              Shared.should_receive(:store_annotations).with({text: @params_text, denotations: @params_denotations, relations: @params_relations, modifications: @params_modifications}, @project, [@doc], {mode: nil, delayed: true})  
              Shared.stub(:delay).and_return(Shared)
              post :create, project_id: @project.id, text: @params_text, denotations: @params_denotations, relations: @params_relations, modifications: @params_modifications, format: 'json'
            end
          end

          context 'when format != json' do
            before do
              @referer_path = docs_path
              request.env["HTTP_REFERER"] = @referer_path
            end

            it 'should execute store_annotations without delayed_job with params[:annotaitons] symbolize_keys' do
              Shared.should_not_receive(:delay)  
              Shared.should_receive(:store_annotations).with({text: @params_text, denotations: @params_denotations, relations: @params_relations, modifications: @params_modifications}, @project, [@doc], {mode: nil})  
              post :create, project_id: @project.id, text: @params_text, denotations: @params_denotations, relations: @params_relations, modifications: @params_modifications, format: 'html'
            end
          end
        end

        context 'when params[:annotaitons] blank and params[:text] blank' do
          before do
            @referer_path = docs_path
            request.env["HTTP_REFERER"] = @referer_path
            post :create, project_id: @project.id, format: 'html'
          end

          it 'should set no annotaitons messages as flash[:notice]' do
            flash[:notice].should eql(I18n.t('controllers.annotations.create.no_annotation'))
          end
        end
      end

      context' when divs blank' do
        before do
          controller.stub(:get_docspec).and_return(['sourcedb', 'sourceid', 'divno'])
          controller.stub(:get_doc).and_return([@doc])
          post :create, project_id: @project.id, format: 'html'
        end

        it 'should set error message as flash[:notice]' do
          flash[:notice].should eql(I18n.t('controllers.annotations.create.no_project_document', :project_id =>@project.id, :sourcedb => nil, :sourceid => nil))
        end

        it 'should redirect_to project_path' do
          response.should redirect_to(project_path(@project.name))
        end
      end 
    end

    context 'when project blank' do
      context 'when format == html' do
        before do
          controller.stub(:get_project).and_return(nil)
          post :create, project_id: 1, format: 'html'
        end

        it 'should redirect_to home_path' do
          response.should redirect_to home_path
        end
      end

      context 'when format == json' do
        before do
          controller.stub(:get_project).and_return(nil)
          post :create, project_id: 1, format: 'json'
        end

        it 'should return unprocessable_entity json' do
          response.body.should eql({status: :unprocessable_entity}.to_json)
        end
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
      
      it 'shoule set headers Access-Control-Allow-Methods' do
        @headers['Access-Control-Allow-Methods'].should eql('POST, GET, OPTIONS')
      end
      
      it 'shoule set headers Access-Control-Allow-Headers' do
        @headers['Access-Control-Allow-Headers'].should eql('Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, X-Prototype-Version')
      end
      
      it 'shoule set headers Access-Control-Allow-Credentials' do
        @headers['Access-Control-Allow-Credentials'].should eql('true')
      end
      
      it 'shoule set headers Access-Control-Max-Age' do
        @headers['Access-Control-Max-Age'].should eql('1728000')
      end
    end
  end

  describe 'generate' do
    before do 
      controller.class.skip_before_filter :authenticate_user!
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @project = FactoryGirl.create(:project, user: @current_user)
      @sourcedb = 'sourcedb'
      @sourceid = 'sourceid'
      @doc = FactoryGirl.create(:doc)
      @referer_path = root_path
      request.env["HTTP_REFERER"] = @referer_path
    end

    context 'when project present' do
      context 'when doc present' do
        before do
          controller.stub(:get_doc).and_return(@doc)
          @annotations = 'annotations'
          controller.stub(:get_annotations).and_return(nil)
          controller.stub(:gen_annotations).and_return(@annotations)
          Shared.stub(:save_annotations) do |annotations, project, doc|
            @attr_annotations = annotations
          end
        end

        context 'when format html' do
          before do
            post :generate, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid
          end

          it 'should redirect_to back' do
            response.should redirect_to @referer_path 
          end

          it 'should set save_annotations as flash[:notice]' do
            flash[:notice].should eql @attr_annotations
          end
        end

        context 'when format html' do
          before do
            post :generate, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid, format: 'json'
          end
          
          it 'should return no content' do
           response.status.should eql 204
          end
        end
      end

      context 'when doc blank' do
        before do
          controller.stub(:get_doc).and_return(nil)
        end

        context 'when format html' do
          before do
            post :generate, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid
          end

          it 'should redirect_to project_path' do
            response.should redirect_to project_path(@project.name)
          end

          it 'should set save_annotations as flash[:notice]' do
            flash[:notice].should eql I18n.t('controllers.annotations.create.no_project_document', :project_id => @project.name, :sourcedb => @sourcedb, :sourceid => @sourceid) 
          end
        end

        context 'when format json' do
          before do
            post :generate, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid, format: 'json'
          end

          it 'should return unprocessable' do
            response.status.should eql 422
          end
        end
      end

      context 'when project blank' do
        before do
          post :generate, project_id: 0, sourcedb: @sourcedb, sourceid: @sourceid
        end

        it 'should return unprocessable' do
          response.should redirect_to home_path
        end
      end
    end
  end

  describe 'project_annotations_zip' do
    context 'when project present' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        Project.any_instance.stub(:annotations_zip_path).and_return(nil)
        @zip_file_name = 'annotations.zip'
        Project.any_instance.stub(:annotations_zip_file_name).and_return(@zip_file_name)
      end

      context 'when annotaitons zip present' do
        before do
          File.stub(:exist?).and_return(true)
          get :project_annotations_zip, project_id: @project.name
        end

        it 'should redirect to project annotations zip path' do
          response.should redirect_to("/annotations/#{@zip_file_name}")
        end
      end

      context 'when annotaitons zip blank' do
        before do
          File.stub(:exist?).and_return(false)
          controller.stub(:render_status_error).and_return(nil)
          controller.stub(:render).and_return(nil)
        end

        it 'should call render_status_error' do
          controller.should_receive(:render_status_error).with(:not_found)
          get :project_annotations_zip, project_id: @project.name
        end
      end
    end
  end

  describe 'delete_project_annotations_zip' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @user = FactoryGirl.create(:user)
      @refrerer = root_path
      request.env["HTTP_REFERER"] = @refrerer
      @project = FactoryGirl.create(:project, user: @user)
      controller.stub(:render).and_return(nil)
    end

    context 'when project present' do
      before do
        @annotations_zip_path = 'annotations.zip'
        Project.any_instance.stub(:annotations_zip_path).and_return(@annotations_zip_path)
      end

      context 'when zip file exists' do
        before do
          File.stub(:exist?).and_return(true)
        end

        context 'when project.user == current_user' do
          before do
            controller.stub(:current_user).and_return(@user)
          end

          context 'when successfully deleted' do
            before do
              File.stub(:unlink).and_return(nil)
            end

            it 'should delete zip file' do
              File.should_receive(:unlink).with(@annotations_zip_path)
              get :delete_project_annotations_zip, project_id: @project.name
            end

            it 'should set deleted message as flash{:notice}' do
              get :delete_project_annotations_zip, project_id: @project.name
              flash[:notice].should eql(I18n.t('views.shared.zip.deleted'))
            end

            it 'should redirect_to previous page' do
              get :delete_project_annotations_zip, project_id: @project.name
              response.should redirect_to(@refrerer)
            end
          end

          context 'when error raised' do
            before do
              @error_message = 'Error'
              File.stub(:unlink).and_raise(@error_message)
            end

            it 'should set deleted message as flash{:notice}' do
              get :delete_project_annotations_zip, project_id: @project.name
              flash[:notice].should eql(@error_message)
            end

            it 'should redirect_to previous page' do
              get :delete_project_annotations_zip, project_id: @project.name
              response.should redirect_to(@refrerer)
            end
          end
        end

        context 'when project.user != current_user' do
          before do
            controller.stub(:current_user).and_return(nil)
          end

          it 'shoud call render_status_error with forbidden' do
            controller.should_receive(:render_status_error).with(:forbidden)
            get :delete_project_annotations_zip, project_id: @project.name
          end
        end
      end
    end

    context 'when project nil' do
      it 'shoud call render_status_error with not_found' do
        controller.should_receive(:render_status_error).with(:not_found)
        get :delete_project_annotations_zip, project_id: 'invalid'
      end
    end
  end
  
  describe 'destroy_all' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @another_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
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
