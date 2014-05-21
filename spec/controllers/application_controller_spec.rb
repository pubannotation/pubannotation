# encoding: UTF-8
require 'spec_helper'

describe ApplicationController do
  before do
    I18n.locale = :en
  end

  controller do
    def after_sign_in_path_for_test(resource_or_scope)
      after_sign_out_path_for(resource_or_scope)
    end
  end
  
  describe 'set_locale' do
    context 'when session[:locale].blank' do
      context 'when locale == :ja' do
        before do
          controller.stub(:request).and_return(double(:request, :env => {'HTTP_ACCEPT_LANGUAGE'=> 'ja'}))
          controller.set_locale
        end
        
        it 'locale.should be :ja' do
          I18n.locale.should eql(:ja)
        end
      end
  
      context 'when locale == :en' do
        before do
          controller.stub(:request).and_return(double(:request, :env => {'HTTP_ACCEPT_LANGUAGE'=> 'en'}))
          controller.set_locale
        end
        
        it 'locale.should be :en' do
          I18n.locale.should eql(:en)
        end
      end
  
      context 'when locale is not accepted' do
        before do
          controller.stub(:request).and_return(double(:request, :env => {'HTTP_ACCEPT_LANGUAGE'=> 'jj'}))
          controller.set_locale
        end
        
        it 'locale.should be :en' do
          I18n.locale.should eql(:en)
        end
      end
    end
    
    context 'when session[:locale] present' do
      context 'when params[:locale] present' do
        context 'when params[:locale] == en' do
          before do
            controller.stub(:params).and_return({:locale => 'en'})
            controller.set_locale
          end
          
          it 'session locale should be en' do
            session[:locale].should eql('en')
          end
          
          it 'I18n locale should be en' do
            I18n.locale.should eql(:en)
          end
        end

        context 'when params[:locale] == ja' do
          before do
            controller.stub(:params).and_return({:locale => 'ja'})
            controller.set_locale
          end
          
          it 'session locale should be ja' do
            session[:locale].should eql('ja')
          end
          
          it 'I18n locale should be ja' do
            I18n.locale.should eql(:ja)
          end
        end

        context 'when params[:locale] is not accepted' do
          before do
            controller.stub(:params).and_return({:locale => 'jj'})
            controller.set_locale
          end
          
          it 'session locale should be nil' do
            session[:locale].should be_nil
          end
          
          it 'I18n locale should be en' do
            I18n.locale.should eql(:en)
          end
        end
      end      
    end
  end
  
  describe 'store_location' do
    before do
      @user_sign_in_path = '/users/sign_in'
      @user_sign_up_path = '/users/sign_up'
      @request_full_path = '/last/request'
      @post_request_full_path = '/last/post'
      controller.stub(:new_user_session_path).and_return(@user_sign_in_path)
      controller.stub(:new_user_registration_path).and_return(@user_sign_up_path)
      controller.stub(:url_for).and_return(@request_full_path)
    end  

    context 'when request.fullpath is not user sign in path and user signup path' do
      before do
        controller.stub(:request).and_return(double(:fullpath => @request_full_path, :method => 'GET', :host => ''))
        controller.store_location
      end
      
      it 'request.fullpath should stored as redirect_path' do
        session[:after_sign_in_path].should eql(@request_full_path)
      end
    end

    context 'when request.fullpath is POST method' do
      before do
        controller.stub(:request).and_return(double(:fullpath => @request_full_path, :method => 'GET'))
        controller.store_location
        controller.stub(:request).and_return(double(:fullpath => @post_request_full_path, :method => 'POST'))
        controller.store_location
      end
      
      it 'POST request.fullpath should not stored as redirect_path' do
        session[:after_sign_in_path].should eql(@request_full_path)
      end
    end

    context 'when request.fullpath is user_sign_in_path' do
      before do
        controller.stub(:request).and_return(double(:fullpath => @request_full_path, :method => 'GET'))
        controller.store_location
        controller.stub(:url_for).and_return(@user_sign_in_path)
        controller.stub(:request).and_return(double(:fullpath => @user_sign_in_path, :method => 'GET'))
        controller.store_location
      end
      
      it 'request.fullpath should not stored as redirect_path and previous fullpath should be stored' do
        session[:after_sign_in_path].should eql(@request_full_path)
      end
    end

    context 'when request.fullpath is user_sign_up_path' do
      before do
        controller.stub(:request).and_return(double(:fullpath => @request_full_path, :method => 'GET'))
        controller.store_location
        controller.stub(:url_for).and_return(@user_sign_up_path)
        controller.stub(:request).and_return(double(:fullpath => @user_sign_up_path, :method => 'GET'))
        controller.store_location
      end
      
      it 'request.fullpath should not stored as redirect_path and previous fullpath should be stored' do
        session[:after_sign_in_path].should eql(@request_full_path)
      end
    end
  end
  
  describe 'after_sign_in_path_for' do
    before do
      @root_path = '/'
      controller.stub(:root_path).and_return(@root_path)  
    end
    
    context 'when session[:after_sign_in_path] exists' do
      before do
        @after_sign_in_path = 'after_sign_in_path'
        session[:after_sign_in_path] = @after_sign_in_path
      end
      
      it 'should return session[:after_sign_in_path]' do
        controller.after_sign_in_path_for(nil).should eql(@after_sign_in_path)
      end
    end

    context 'when session[:after_sign_in_path] does not exists' do
      before do
        @after_sign_in_path = 'after_sign_in_path'
        session[:after_sign_in_path] = nil
      end
      
      it 'should return root_path' do
        controller.after_sign_in_path_for(nil).should eql(@root_path)
      end
    end
  end
  
  describe 'after_sign_out_path' do
    before do
      @user = FactoryGirl.create(:user)
      @referrer = 'http://example.cop'
      controller.request.stub referrer: @referrer
    end
    
    it "should return.referrer" do
      controller.after_sign_in_path_for_test(@user).should eql(@referrer)
    end
  end
  
  describe 'get_docspec' do
    context 'when div_id present' do
      before do
        @params = {sourcedb: 'sourcedb', sourceid: 'sourceid', div_id: 1}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return params[:div_id] as serial' do
        @result.should eql [@params[:sourcedb], @params[:sourceid], @params[:div_id], nil]
      end
    end
    
    context 'when div_id blank' do
      before do
        @params = {sourcedb: 'sourcedb', sourceid: 'sourceid'}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return 0 as serial' do
        @result.should eql [@params[:sourcedb], @params[:sourceid], 0, nil]
      end
    end

    context 'when id present' do
      before do
        @params = {sourcedb: 'sourcedb', sourceid: 'sourceid', id: 10}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return params[:id] as id' do
        @result.should eql [@params[:sourcedb], @params[:sourceid], 0, @params[:id]]
      end
    end
  end
  
  describe 'get_project' do
    before do
      @user = FactoryGirl.create(:user)
    end

    context 'when project exists' do
      context 'and when project.accessibility == 1' do
        before do
          @current_user = FactoryGirl.create(:user)
          controller.stub(:user_signed_in?).and_return(false)
          @project = FactoryGirl.create(:project, :accessibility => 1, :user => @user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs project and nil' do
          @result.should eql([@project, nil])
        end
      end

      context 'and when project.accessibility !=1 and project.user == current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @project = FactoryGirl.create(:project, :accessibility => 2, :user => @current_user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs project and nil' do
          @result.should eql([@project, nil])
        end
      end

      context 'and when project.accessibility !=1 and project.user != current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @project = FactoryGirl.create(:project, :accessibility => 2, :user => @user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs nil and message which notice annotationset is private' do
          @result.should eql([nil, I18n.t('controllers.application.get_project.private', :project_name => @project.name)])
        end
      end
    end
    
    context 'when project does not exists' do
      before do
        @project_name = 'Project name'
        @result = controller.get_project(@project_name)
      end
      
      it 'returns nil and message notice annotasion set does not exist' do
        @result.should eql([nil, I18n.t('controllers.application.get_project.not_exist', :project_name => @project_name)])
      end
    end
  end
  
  describe 'get_projects' do
    before do
      @another_user = FactoryGirl.create(:user)
      @current_user = FactoryGirl.create(:user)
      @project_accessibility_1_and_another_user_project = FactoryGirl.create(:project, :user => @another_user, :accessibility => 1) 
      @project_accessibility_not_1_and_another_user_project = FactoryGirl.create(:project, :user => @another_user, :accessibility => 2) 
      @project_accessibility_1_and_current_user_project = FactoryGirl.create(:project, :user => @current_user, :accessibility => 1) 
      @project_accessibility_not_1_and_current_user_project = FactoryGirl.create(:project, :user => @current_user, :accessibility => 2) 
      current_user_stub(@current_user)
    end
    
    context 'when optons present' do
      context 'when optoins[:doc] present' do
        before do
          @doc = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :project_id => @project_accessibility_1_and_another_user_project.id, :doc_id => @doc.id)  
          FactoryGirl.create(:docs_project, :project_id => @project_accessibility_not_1_and_another_user_project.id, :doc_id => @doc.id)  
          FactoryGirl.create(:docs_project, :project_id => @project_accessibility_1_and_current_user_project.id, :doc_id => @doc.id)  
          FactoryGirl.create(:docs_project, :project_id => @project_accessibility_not_1_and_current_user_project.id, :doc_id => @doc.id)  
        end
        
        context 'when associate projects present' do
          before do
            @result = controller.get_projects(:doc => @doc)
          end
          
          it 'should include included in docs.projects' do
            @result.should =~ @doc.projects
          end
        end
      end
    end
    
    context 'when options blank' do
      before do
        @result = controller.get_projects()
      end
      
      it 'should include accessibility = 1 and another users project' do
        @result.should include(@project_accessibility_1_and_another_user_project)
      end
      
      it 'should not include accessibility != 1 and another users project' do
        @result.should_not include(@project_accessibility_not_1_and_another_user_project)
      end
      
      it 'should include accessibility = 1 and current users project' do
        @result.should include(@project_accessibility_1_and_current_user_project)
      end
      
      it 'should include accessibility != 1 and current users project' do
        @result.should include(@project_accessibility_not_1_and_current_user_project)
      end
    end
  end
  
  describe 'get_doc' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1)
    end

    context 'when id passed' do
      before do
        @result = controller.get_doc(nil, nil, nil, nil, @doc.id)
      end

      it 'should return doc and nil' do
        @result.should eql([@doc, nil])
      end
    end

    context 'when id not passed' do
      before do
        @result = controller.get_doc(@doc.sourcedb, @doc.sourceid, @doc.serial)
      end

      it 'should return doc and nil' do
        @result.should eql([@doc, nil])
      end
    end

    context 'when doc present' do
      context 'when project passed' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        end
        
        context 'when doc.projects include project' do
          before do
            @project.docs << @doc
            @result = controller.get_doc(@doc.sourcedb, @doc.sourceid.to_s, @doc.serial, @project)
          end
          
          it 'should return doc and nil' do
            @result.should eql([@doc, nil])
          end
        end
        
        context 'when doc.projects not include project' do
          before do
            @result = controller.get_doc(@doc.sourcedb, @doc.sourceid.to_s, @doc.serial, @project)
          end
          
          it 'should return nil and notice' do
            @result.should eql([nil, I18n.t('controllers.application.get_doc.not_belong_to', :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :project_name => @project.name)])
          end
        end
      end
    end
    
    context 'when doc does not exists' do
      before do
        @result = controller.get_doc(nil, nil, nil, nil)
      end
      
      it 'should return nil and no annotation message' do
        @result.should eql([nil, I18n.t('controllers.application.get_doc.no_annotation', :sourcedb => nil, :sourceid => nil) ])
      end
    end
  end
  
  describe 'get_divs' do
    context 'when divs present' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => '1')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      end

      context 'and when divs belongs to project' do
        before do
          @project.docs << @doc
          @result = controller.get_divs(@doc.sourceid.to_s, @project)
        end
        
        it 'should return blank array and message doc does not belongs to the annotation' do
          @result[0].first.should eql(@doc) 
          @result[1].should be_nil
        end
      end
      
      context 'and when divs.first.projects exclude project' do
        before do
          @result = controller.get_divs(@doc.sourceid.to_s, @project)
        end
        
        it 'should return blank array and message doc does not belongs to the annotation' do
          @result[0].should be_blank
          @result[1].should eql I18n.t('controllers.application.get_divs.not_belong_to', :sourceid => @doc.sourceid, :project_name => @project.name)
        end
      end
    end
    
    context 'when divs is blank' do
      before do
        @sourceid = 'sourceid invalid'
        @result = controller.get_divs(@sourceid, nil)
      end
      
      it 'should return nil and no annotation message' do
        @result[0].should be_blank
        @result[1].should eql I18n.t('controllers.application.get_divs.no_annotation', :sourceid => @sourceid)
      end
    end
  end
  
  describe 'rewrite ascii' do
    before do
      @get_ascii_text = 'ASCII TEXT'
      controller.stub(:get_ascii_text).and_return(@get_ascii_text)
      @doc = FactoryGirl.create(:doc, :body => 'docment body')
      @former_doc_body = @doc.body
      @result = controller.rewrite_ascii([@doc])
    end
    
    it 'should replace document body' do
      @result[0].body.should_not eql(@former_doc_body)
      @doc.body.should_not eql(@former_doc_body)
    end
    
    it 'should include passed doc' do
      @result.should include(@doc)
    end
  end
  
  describe 'archive_texts' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1, :section => 'section')
      controller.stub(:send_file).and_return('send file')
      @result = controller.archive_texts([@doc]) 
    end
    
    it 'return close tempfile' do
      @result.should be_nil
    end
  end
  
  describe 'archive_annotation' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_1 = FactoryGirl.create(:doc)
      @project.docs << @doc_1 
      @doc_2 = FactoryGirl.create(:doc)
      @project.docs << @doc_2 
      @result = controller.archive_annotation(@project.name)
    end
    
    it 'should returns all of project docs in array' do
      (@result - [@doc_1, @doc_2]).should be_blank
    end
  end
  
  describe 'get_conversion' do
    context 'when response.code is 200' do
      before do
        @project = FactoryGirl.create(:project,
         :name => 'Project Name',
         :description => 'This is project description',
         :user => FactoryGirl.create(:user))
        VCR.use_cassette 'controllers/application/get_convertion/response_200' do
          @result = controller.get_conversion(@project, 'http://bionlp.dbcls.jp/ge2rdf')
        end
      end
      
      it 'should return response' do
        @result.should be_present
      end
    end
    
    context 'when response.code is not 200' do
     before do
        VCR.use_cassette 'controllers/application/get_convertion/response_not_200' do
          @result = controller.get_conversion(@project, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'gen_annotations' do
    context 'when response.code is 200' do
      before do
        @annotation = {:text => 'text', :others => 'others'}
        VCR.use_cassette 'controllers/application/gen_annotation/response_200' do
          @result = controller.gen_annotations(@annotation, 'http://nlp.dbcls.jp/biosentencer/')
        end
      end
      
      it 'should return response' do
        @result.should be_present
      end
    end
    
    context 'when response.code is not 200' do
     before do
        @annotation = {:text => '', :others => 'others'}
        VCR.use_cassette 'controllers/application/gen_annotations/response_not_200' do
          @result = controller.gen_annotations(@annotation, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'save annotations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end

    context 'when denotations exists' do
      before do
        @relations = 'relations'
        @modification = 'modification'
        @annotations = {:denotations => 'denotations', :instances => ['instance'], :relations => @relations, :modifications => @modification}
        controller.stub(:clean_hdenotations).and_return('clean_hdenotations')
        @realign_denotations = 'realign_denotations'
        controller.stub(:realign_denotations).and_return(@realign_denotations)
        controller.stub(:save_hdenotations) do |denotations, project, doc|
          @denotations = denotations
        end
        controller.stub(:save_hrelations) do |relations, project, doc|
          @relations = relations
        end
        controller.stub(:save_hmodifications) do |modifications, project, doc|
          @modifications = modifications
        end
        @result = controller.save_annotations(@annotations, @project, @doc)
      end

      it 'should exec save_hdenotations' do
        @denotations.should eql(@realign_denotations)
      end

      it 'should exec save_hrelations' do
        @relations.should eql(@relations)
      end

      it 'should exec save_hdenotations' do
        @modifications.should eql(@modifications)
      end

      it 'should return notice message' do
        @result.should eql('Annotations are successfully created/updated.')
      end
    end
    
    context 'denotations does not exists' do
      before do
        @annotations = {:denotations => nil} 
        controller.stub(:clean_hdenotations).and_return(nil)
        @result = controller.save_annotations(@annotations, @project, @doc)
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'get_denotations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
    end
    
    context 'when doc find_by_sourcedb_and_sourceid_and_serial exist' do
      before do
        @doc.projects << @project
      end
      
      context 'when doc.project.find_by_name(project_name) exists' do
        before do
          @project_another = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
          @denotation_another = FactoryGirl.create(:denotation, :project => @project_another, :doc => @doc)
          @denotations = controller.get_denotations(@project.name, @doc.sourcedb, @doc.sourceid.to_s, @doc.serial)       
        end
        
        it 'should returns doc.denotations where project_id = project.id' do
          (@denotations - [@denotation]).should be_blank
        end
      end
      
      
      context 'when doc.project.find_by_name(project_name) does not exists' do
        before do
          @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
          @denotations = controller.get_denotations('none project name', @doc.sourcedb.to_s, @doc.sourceid.to_s, @doc.serial)       
        end
        
        it 'should return doc.denotations' do
          (@denotations - @doc.denotations).should be_blank
        end
      end
    end

    context 'when doc find_by_sourcedb_and_sourceid_and_serial does not exist' do
      before do
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      end
      
      context 'when project find_by_name exist' do
        before do
          @denotations = controller.get_denotations(@project.name, 'nil', 'nil', 'nil')       
        end
        
        it 'should return project.denotations' do
          (@denotations - @project.denotations).should be_blank
        end
      end
      
      context 'when project find_by_name does not exist' do
        before do
          @denotations = controller.get_denotations('', 'nil', 'nil', 'nil')       
        end
        
        it 'should return all denotations' do
          (Denotation.all - @denotations).should be_blank
        end
      end
    end
  end
  
  describe 'get_hdenotations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      controller.stub(:get_cattanns).and_return([@denotation])
      @get_hash = 'get hash'
      Denotation.any_instance.stub(:get_hash).and_return(@get_hash)
      @hdenotations = controller.get_hdenotations('', '', '')
    end
    
    it 'should return array denotation.get_hash' do
      @hdenotations.should eql([@get_hash])
    end
  end
  
  describe 'clean_hdenotations' do
    context 'when format error' do
      context 'when denotation and begin does not present' do
        before do
          @denotation = {:id => 'id', :end => '5', :obj => 'Category'}
          denotations = Array.new
          denotations << @denotation
          @result = controller.clean_hdenotations(denotations)
        end
        
        it 'should return nil and format error' do
          @result.should eql([nil, "format error #{@denotation}"])
        end
      end
  
      context 'when obj does not present' do
        before do
          @denotation = {:id => 'id', :begin => '`1', :end => '5', :obj => nil}
          denotations = Array.new
          denotations << @denotation
          @result = controller.clean_hdenotations(denotations)
        end
        
        it 'should return nil and format error' do
          @result.should eql([nil, "format error #{@denotation}"])
        end
      end
    end
    
    context 'when correct format' do
      before do
        @begin = '1'
        @end = '5'
        @denotations = Array.new
      end

      context 'when id is nil' do
        before do
          @denotation = {:span => {:begin => @begin, :end => @end}, :obj => 'Category'}
          @denotations << @denotation
          @result = controller.clean_hdenotations(@denotations)
        end
        
        it 'should return T + num id' do
          @result[0][0][:id].should eql('T1')
        end
      end

      context 'when denotation exists' do
        before do
          @denotation = {:id => 'id', :span => {:begin => @begin, :end => @end}, :obj => 'Category'}
          @denotations << @denotation
          @result = controller.clean_hdenotations(@denotations)
        end
        
        it 'should return ' do
          @result.should eql([[{:id => @denotation[:id], :obj => @denotation[:obj], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end

      context 'when denotation does not exists' do
        before do
          @denotation = {:id => 'id', :begin => @begin, :end => @end, :obj => 'Category'}
          @denotations << @denotation
          @result = controller.clean_hdenotations(@denotations)
        end
        
        it 'should return with denotation' do
          @result.should eql([[{:id => @denotation[:id], :obj => @denotation[:obj], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end
    end
  end
  
  describe 'save_hdenotations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @associate_project_denotations_count_1 = FactoryGirl.create(:project, :denotations_count => 0)
      @associate_project_denotations_count_1.docs << @doc
      @associate_project_denotations_count_1.reload
      @di = 1
      1.times do
        FactoryGirl.create(:denotation, :begin => @di, :project_id => @associate_project_denotations_count_1.id, :doc_id => @doc.id)
        @di += 1
      end
      @associate_project_denotations_count_1.reload
      @doc_2 = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '12', :serial => 1, :section => 'section', :body => 'doc body')
      @associate_project_denotations_count_2 = FactoryGirl.create(:project, :denotations_count => 0)
      @associate_project_denotations_count_2.docs << @doc_2
      @associate_project_denotations_count_2.reload
      2.times do
        FactoryGirl.create(:denotation, :begin => @di, :project_id => @associate_project_denotations_count_2.id, :doc_id => @doc_2.id)
        @di += 1
      end
      @associate_project_denotations_count_2.reload
      @project.associate_projects << @associate_project_denotations_count_1
      @project.associate_projects << @associate_project_denotations_count_2
      
      @hdenotation = {:id => 'hid', :span => {:begin => 1, :end => 10}, :obj => 'Category'}
      @hdenotations = Array.new
      @hdenotations << @hdenotation
      @result = controller.save_hdenotations(@hdenotations, @associate_project_denotations_count_1, @doc) 
      @denotation = Denotation.find_by_hid(@hdenotation[:id])
    end
    
    it 'should save successfully' do
      @result.should be_true
    end
    
    it 'should save hdenotation[:id] as hid' do
      @denotation.hid.should eql(@hdenotation[:id])
    end
    
    it 'should save hdenotation[:span][:begin] as begin' do
      @denotation.begin.should eql(@hdenotation[:span][:begin])
    end
    
    it 'should save hdenotation[:span][:end] as end' do
      @denotation.end.should eql(@hdenotation[:span][:end])
    end
    
    it 'should save hdenotation[:obj] as obj' do
      @denotation.obj.should eql(@hdenotation[:obj])
    end

    it 'should save project.id as project_id' do
      @denotation.project_id.should eql(@associate_project_denotations_count_1.id)
    end

    it 'should save doc.id as doc_id' do
      @denotation.doc_id.should eql(@doc.id)
    end
    
    it 'should project.denotations_count should equal 0 before save' do
      @project.denotations_count.should eql(0)
    end

    it 'should incliment project.denotations_count after denotation saved' do
      @project.reload
      @project.denotations_count.should eql((@associate_project_denotations_count_1.denotations_count + @associate_project_denotations_count_2.denotations_count) *2  + 1)
    end
      
    it 'associate_projectproject.denotations_count should equal 1 before save' do
      @associate_project_denotations_count_1.denotations_count.should eql(1)
    end
    
    it 'associate_projectproject.denotations_count should incremented after save' do
      @associate_project_denotations_count_1.reload
      @associate_project_denotations_count_1.denotations_count.should eql(2)
    end
    
    it 'associate_projectproject.denotations_count should remain' do
      @associate_project_denotations_count_2.reload
      @associate_project_denotations_count_2.denotations_count.should eql(2)
    end
  end
  
  describe 'chain_denotations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @denotation_1 = FactoryGirl.create(:denotation, :hid => 'A1', :project => @project, :doc => @doc)
      @denotation_2 = FactoryGirl.create(:denotation, :hid => 'A2', :project => @project, :doc => @doc)
      @denotation_3 = FactoryGirl.create(:denotation, :hid => 'A3', :project => @project, :doc => @doc)
      @denotations_s = [@denotation_1, @denotation_2, @denotation_3]
      @result = controller.chain_denotations(@denotations_s)
    end
    
    it 'shoulr return denotations_s' do
      @result.should eql(@denotations_s)
    end
  end
  
  describe 'get_relations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :project => @project)
      @instance = FactoryGirl.create(:instance, :project => @project, :obj => @denotation)
      @subinsrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :project => @project)
    end

    context 'when doc find by sourcedb and source id and serial exists' do
      context 'when doc.projects.find by project name exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations(@project.name, @doc.sourcedb, @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels wose project_id = project.id ' do
          (@relations - [@subcatrel, @subinsrel]).should be_blank
        end
      end

      context 'when doc.projects.find by project name exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations('', @doc.sourcedb, @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels' do
          (@relations - [@subcatrel, @subinsrel]).should be_blank
        end
      end
    end
    
    context 'when doc find by sourcedb and source id and serial does not exists' do
      context 'when Project.find_by_name(project_name) exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations(@project.name, 'non existant source db', @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return project.relations' do
          (@relations - @project.relations).should be_blank
        end
      end

      context 'when Project.find_by_name(project_name) does not exists' do
        before do
          @doc.projects << @project
          5.times do
            FactoryGirl.create(:relation, :obj => @denotation, :project => @project)
          end
          @relations = controller.get_relations('non existant project name', 'non existant source db', @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return Rellann.all' do
          (Relation.all - @relations).should be_blank
        end
      end
    end
  end
  
  describe 'get_hrelations' do
    before do
      doc = FactoryGirl.create(:doc)
      denotation = FactoryGirl.create(:denotation, :project_id => 1, :doc => doc )
      @subcatrel = FactoryGirl.create(:subcatrel, :obj_id => 1, :project_id => 1, :subj_id => denotation.id)
      controller.stub(:get_relations).and_return([@subcatrel])
      Relation.any_instance.stub(:get_hash).and_return(@subcatrel.id)
      @hrelations = controller.get_hrelations('', '', '', '')
    end
    
    it 'should return array relations.get_hash got by get_relations' do
      @hrelations.should eql([@subcatrel.get_hash])
    end
  end
  
  describe 'save_hrelations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @hrelations = Array.new
    end
    
    describe 'before exec' do
      it 'Modification is empty' do
        Modification.all.should be_blank
      end
    end

    describe 'after exec' do
      before do
        @hrelation = {:id => 'hid', :pred => 'pred', :subj => @denotation.hid, :obj => @denotation.hid}
        @hrelations << @hrelation
        @result = controller.save_hrelations(@hrelations, @project, @doc)
      end

      it '' do
        Relation.where(
          :hid => @hrelation[:id], 
          :pred => @hrelation[:pred], 
          :subj_id => @denotation.id, 
          :subj_type => @denotation.class, 
          :obj_id => @denotation.id, 
          :obj_type => @denotation.class, 
          :project_id => @project.id
        ).should be_present
      end
    end
  end
  
  describe 'get_modifications' do
    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name2")
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :project => @project)
      end
      
      context 'and when doc.projects.find_by_name(project_name) exists' do
        before do
          @subcatrelmod = FactoryGirl.create(:modification, :obj => @subcatrel, :project => @project)
          @subcatrelmod_2 = FactoryGirl.create(:modification, :obj => @subcatrel, :project => @project_2)
          @doc.projects << @project
          @modifications = controller.get_modifications(@project.name, @doc.sourcedb, @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return doc.subcatrelmods  where project_id = project.id' do
          @modifications.should =~ [@subcatrelmod]
        end
      end
      
      context 'and when doc.projects.find_by_name(project_name) does not exists' do
        before do
          @subcatrelmod = FactoryGirl.create(:modification, :obj => @subcatrel, :project_id => 80)
          @doc.projects << @project
          @modifications = controller.get_modifications('', @doc.sourcedb, @doc.sourceid.to_s, @doc.serial)
        end
        
        it 'should return doc.subcatrelmods' do
          (@modifications - [@subcatrelmod]).should be_blank
        end
      end
    end

    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) does not exists' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      end
      
      context 'Project.find_by_name(project_name) exists' do
        before do
          @modification = FactoryGirl.create(:modification, :obj => @denotation, :project => @project)
          @modifications = controller.get_modifications(@project.name, '', '', '')
        end
        
        it 'should return project.modifications' do
          (@modifications - [@modification]).should be_blank
        end
      end
      
      context 'Project.find_by_name(project_name) present' do
        before do
          @project_2 = FactoryGirl.create(:project)
          5.times do |i|
            FactoryGirl.create(:modification, :obj => @denotation, project: @project_2)
          end
          @modification = FactoryGirl.create(:modification, :obj => @denotation, project: @project)
          @modifications = controller.get_modifications(@project.name, '', '', '')
        end
        
        it 'should return project.modifications' do
          (@modifications - @project.modifications).should be_blank
        end
      end

      context 'Project.find_by_name(project_name) does not exists' do
        before do
          5.times do |i|
            FactoryGirl.create(:modification, :obj => @denotation, :project_id => i)
          end
          @modifications = controller.get_modifications('', '', '', '')
        end
        
        it 'should return Modification.all' do
          (Modification.all - @modifications).should be_blank
        end
      end
    end
  end
  
  describe 'get_hmodifications' do
    before do
      @denotation = FactoryGirl.create(:denotation)
      @modification = FactoryGirl.create(:modification, :obj => @denotation, :project_id => 1)
      controller.stub(:get_modifications).and_return([@modification])
      Modification.any_instance.stub(:get_hash).and_return(@modification.id)
      @hmodifications = controller.get_hmodifications('', '', '')
    end
    
    it 'should return array modifications.get_hash' do
      @hmodifications.should eql([@modification.id])
    end
  end
  
  describe 'save_hmodifications' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
    end
    
    context 'when hmodifications[:obj] match /^R/' do
      before do
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, :project => @project)
        @hmodification = {:id => 'hid', :pred => 'type', :obj => @subcatrel.hid}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = controller.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.instances' do
        Modification.where(
          :hid => @hmodification[:id],
          :pred => @hmodification[:pred],
          :obj_id => @subcatrel.id,
          :obj_type => @subcatrel.class
        ).should be_present
      end
    end

    context 'when hmodifications[:obj] not match /^R/' do
      before do
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @hmodification = {:id => 'hid', :pred => 'type', :obj => @denotation.hid}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = controller.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.instances' do
        Modification.where(
          :hid => @hmodification[:id],
          :pred => @hmodification[:pred],
          :obj_id => @denotation.id,
          :obj_type => @denotation.class
        ).should be_present
      end
    end
  end
  
  describe 'realign_denotations' do
    context 'when denotations is nil' do
      before do
        @result = controller.realign_denotations(nil, '', '')
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
    
    context 'when canann exists' do
      before do
        @begin = 1
        @end = 5
        @denotation = {:span => {:begin => @begin, :end => @end}}
        @denotations = Array.new
        @denotations << @denotation
        @result = controller.realign_denotations(@denotations, 'from text', 'end of text')
      end
      
      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end
  
  describe 'adjust_denotations' do
    context 'when denotations is nil' do
      before do
        @result = controller.adjust_denotations(nil, '')
      end

      it 'should return nil' do
        @result.should be_nil
      end
    end

    context 'when denotations exists' do
      before do
        @begin = 1
        @end = 5
        @denotation = {:span => {:begin => @begin, :end => @end}}
        @denotations = Array.new
        @denotations << @denotation
        @result = controller.adjust_denotations(@denotations, 'this is an text')
      end

      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end
  
  describe 'get_navigator' do
    before do
      controller.stub(:request).and_return(double(:fullpath => 'first/second'))
      @navigator = controller.get_navigator()
    end
    
    it 'return split request.fullpath by slash' do
      @navigator.should eql([["first", "/first"], ["second", "/first/second"]])
    end
  end
  
  describe 'render_status_error(status)' do
    before do
      controller.should_receive(:render).with("shared/status_error", {:status=>:forbidden}).and_return(true)
      controller.render_status_error(:forbidden)
    end
    
    it 'should set flash[:error]' do
      flash[:error].should eql(I18n.t("errors.statuses.forbidden"))
    end
  end
end
