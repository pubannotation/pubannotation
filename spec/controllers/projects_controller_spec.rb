# encoding: utf-8
require 'spec_helper'

describe ProjectsController do
  before do
    controller.class.skip_before_filter :authenticate_user!
  end
  
  describe 'index' do
    before do
      controller.stub(:current_user).and_return(nil)
    end
    
    context 'when sourcedb exists' do
      context 'and when doc exists' do
        context 'and when projects exists' do
          before do
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
            controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, @doc.serial])
            @project_user = FactoryGirl.create(:user, username: 'user name')
            @project = FactoryGirl.create(:project, :user => @project_user)
            @docs_projects = double(:docs_projects)
            Doc.any_instance.stub(:projects).and_return(@docs_projects)
            @accessble_projects = double(:accessible)
            @docs_projects.stub(:accessible).and_return(@accessble_projects)
            @sort_by_params = 'sort_by_params'
            @accessble_projects.stub(:sort_by_params).and_return(@sort_by_params)
          end
          
          context 'and when format html' do
            before do
              get :index
            end

            it '@projects should eql @doc.projects.accessible.sort_by_params' do
              assigns[:projects].should eql(@sort_by_params)
            end
            
            it 'should render template' do
              response.should render_template('index')
            end
          end
        end
        
        context 'and when projects does not exist' do
          before do
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
            controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, @doc.serial])
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            get :index
          end
          
          it 'should redirect to home_path' do
            response.should redirect_to(home_path)
          end
        end
      end

      context 'and when doc does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1)
          controller.stub(:get_docspec).and_return([@doc.sourcedb, @doc.sourceid, nil])
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        end
        
        context 'and when format html' do
          before do
            get :index
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
      end
    end

    context 'when sourcedb does not exists' do
      before do
        @user = FactoryGirl.create(:user)
        current_user_stub(@user)
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @accessble_projects = double(:accessible)
        Project.stub(:accessible).and_return(@accessble_projects)
        @sort_by_params = 'sort_by_params'
        @accessble_projects.stub(:sort_by_params).and_return(@sort_by_params)
        get :index
      end

      it '@projects should eql Project.accessible.sort_by_params' do
        assigns[:projects].should eql(@sort_by_params)
      end
      
      it 'should render template' do
        response.should render_template('index')
      end
    end
    
    context 'when format is json' do
      before do
        Project.stub(:accessible).and_return(Project.includes(:user))
        get :index, :format => 'json'
      end
      
      it 'should render json' do
        response.body.should eql(Project.all.to_json)
      end
    end
  end
  
  describe 'show' do
    context 'when project exists' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        controller.stub(:get_project).and_return(@project)
      end
      
      context 'when processing associate projects' do
        before do
          @project.pending_associate_projects_count = 1
          get :show, :id => @project.id
        end  
        
        it 'should set processing notice message' do
          flash[:notice].should eql(I18n.t('controllers.projects.show.pending_associate_projects'))
        end
      end
      
      context 'when format json' do
        before do
          @json = {val: 'val'}
          @project.stub(:json).and_return(@json)
          get :show, format: 'json', :id => @project.id
        end  
        
        it 'should return project.json' do
          response.body.should eql(@json.to_json)
        end
      end
      
      context 'when sourceid exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 'serial')
          controller.stub(:get_docspec).and_return(['', 'sourdeid', ''])
          controller.stub(:get_doc).and_return(@doc, 'notice')
          get :show, :id => @project.id
        end
        
        it 'should render template' do
          response.should render_template('show')
        end
      end
      
      context 'when sourceid does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 'serial')
          Doc.stub(:order_by).and_return(Doc.where('id > ?', 0))
          controller.stub(:get_doc).and_return(@doc, 'notice')
          get :show, :id => @project.id
        end
        
        it 'should render template' do
          response.should render_template('show')
        end
      end
    end

    context 'when project does not exists' do
      context 'and when doc does not exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 'sourceid', :serial => 'serial')
          get :show, :id => 1
        end
        
        it '' do
          response.should redirect_to(home_path)
        end
      end
    end
  end
  
  describe 'new' do

    context 'when format html' do
      before do
        get :new
      end
      
      it 'should render template' do
        response.should render_template('new')
      end
      
      it 'should set new record' do
        assigns[:project].new_record?.should be_true
      end
    end

    context 'when format json' do
      before do
        get :new, :format => 'json'
      end
      
      it 'should render json' do
        response.body.should eql(assigns[:project].to_json)
      end
      
      it 'should set new record' do
        assigns[:project].new_record?.should be_true
      end
    end
  end
  
  describe 'edit' do
    context 'when updatable' do
      before do
        @project = FactoryGirl.create(:project, :name => 'project name', :user => FactoryGirl.create(:user))
        @project.stub(:updatable_for?).and_return(true)
        @get_docspec = ['sourcedb', 'sourceid', 'serial']
        controller.stub(:get_docspec).and_return(@get_docspec)
        controller.stub(:updatable?).and_return(true)
        get :edit, :id => @project.name
      end
      
      it 'should render template' do
        response.should render_template('edit')
      end
      
      it 'should assing sourcedb' do
        assigns[:sourcedb].should eql(@get_docspec[0])
      end
      
      it 'should assing sourceid' do
        assigns[:sourceid].should eql(@get_docspec[1])
      end
      
      it 'should assing serial' do
        assigns[:serial].should eql(@get_docspec[2])
      end
      
    end
  end
  
  describe 'create' do
    before do
      current_user_stub(FactoryGirl.create(:user))  
      controller.class.skip_before_filter :http_basic_authenticate
    end
    
    context 'when saved successfully' do
      before do
        @project_name = 'ansnet name'
      end

      context 'when format html' do
        context 'when associate_maintainers present' do
          before do
            @associate_maintainer_user_1 = FactoryGirl.create(:user, :username => 'Associate Maintainer1')
            @associate_maintainer_user_2 = FactoryGirl.create(:user, :username => 'Associate Maintainer2')
            post :create, :project => {:name => 'ansnet name'}, :usernames => [@associate_maintainer_user_1.username, @associate_maintainer_user_2.username]
          end
          
          it 'should redirect to project_path' do
            response.should redirect_to(project_path('ansnet name'))
          end
          
          it 'should ass associate_maintainers' do
            Project.last.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}.should =~ [@associate_maintainer_user_1, @associate_maintainer_user_2]
          end
        end
        
        context 'when associate_projects blank' do
          before do
            post :create, :project => {:name => 'ansnet name'}
          end
          
          it 'should redirect to project_path' do
            response.should redirect_to(project_path('ansnet name'))
          end
        end
        
        context 'when associate_projects present' do
          before do
            @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :denotations_count => 30, :relations_count => 40)
            @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 2, :denotations_count => 3, :relations_count => 4)
            @project_name = 'ansnet name'
          end
          
          describe 'before post' do
            it 'associate project should not have projects' do
              @associate_project_1.projects.should be_blank
            end       
                 
            it 'associate project should not have projects' do
              @associate_project_2.projects.should be_blank
            end            
          end
          
          describe 'after post' do
            before do
              post :create, :project => {:name => @project_name}, :associate_projects => {
                  :name => {'0' => @associate_project_1.name, '1' => @associate_project_2.name}
              }
              @associate_project_1.reload
              @associate_project_2.reload
            end
            
            it 'associate project should have projects' do
              @associate_project_1.projects.should be_present
            end
            
            it 'associate project should equal created project' do
              @associate_project_1.projects.should include(Project.find_by_name(assigns[:project].name))
            end
            
            it 'associate project should have projects' do
              @associate_project_2.projects.should be_present
            end
            
            it 'associate project should equal created project' do
              @associate_project_2.projects.should include(Project.find_by_name(assigns[:project].name))
            end
            
            it 'should increment pmdocs_count by associate projects' do
              Project.find_by_name(assigns[:project].name).pmdocs_count.should eql(@associate_project_1.pmdocs.count + @associate_project_2.pmdocs.count)
            end
             
            it 'should increment pmcdocs_count by associate projects' do
              Project.find_by_name(assigns[:project].name).pmcdocs_count.should eql(@associate_project_1.pmcdocs.count + @associate_project_2.pmcdocs.count)
            end
            
            it 'should increment denotations_count by associate projects' do
              Project.find_by_name(assigns[:project].name).denotations_count.should eql(@associate_project_1.denotations.count + @associate_project_2.denotations.count)
            end
            
            it 'should increment relations_count by associate projects' do
              Project.find_by_name(assigns[:project].name).relations_count.should eql(@associate_project_1.relations.count + @associate_project_2.relations.count)
            end
             
            it 'should redirect to project_path' do
              response.should redirect_to(project_path('ansnet name'))
            end
          end
        end
      end

      context 'when format json' do
        before do
          controller.stub(:params).and_return({locale: '', project: double('project', class: ActionDispatch::Http::UploadedFile, tempfile: '')} )
          @name = 'json project'
          File.stub(:read).and_return({name: @name, relations_count: 3}.to_json)
          @user = FactoryGirl.create(:user)
          post :create, :format => 'json'
        end
        
        it 'should set attr_accessible columns only' do
          assigns[:project][:relations_count].should eql(0)
        end

        it 'should return http response created as status' do
          response.status.should eql(201)
        end

        it 'should return project path as location' do
          response.location.should eql("http://#{request.env['HTTP_HOST']}#{project_path(assigns[:project].id)}")
        end
      end
    end
    
    context 'when saved unsuccessfully' do
      context 'when format html' do      
        before do
          post :create, :project => {:name => nil}
        end
        
        it 'should render new template' do
          response.should render_template('new')
        end
      end
      
      context 'when format json' do      
        before do
          post :create, :format => 'json', :project => {:name => nil}
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:project].errors.to_json)
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
  end
  
  describe 'update' do
    context 'when updatable' do
      before do
        current_user = FactoryGirl.create(:user)
        current_user_stub(current_user)
        @project = FactoryGirl.create(:project, :name => 'project name', :user => current_user)
        @project.stub(:updatable_for?).and_return(true)
      end
      
      context 'when update successfully' do
        context 'when usernames nil' do
          before do
            @params_project = {:name => 'new_project_name'}  
          end
          
          context 'and when format html' do
            before do
              post :update, :id => @project.id, :project => @params_project          
            end
            
            it 'should redirect to project_path' do
              response.should redirect_to(project_path(@params_project[:name]))
            end
          end
    
          context 'and when format json' do
            before do
              post :update, :id => @project.id, :format => 'json', :project => @params_project          
            end
            
            it 'should return response blank header' do
              response.header.should be_blank
            end
          end
        end
        
        context 'when usernames present' do
          before do
            @associate_maintainer_user_1 = FactoryGirl.create(:user, :username => 'User1')
            @associate_maintainer_user_2 = FactoryGirl.create(:user, :username => 'User2')
            post :update, :id => @project.id, :project => @params_project,
              :usernames => [@associate_maintainer_user_1.username, @associate_maintainer_user_2.username]         
          end
          
          it 'should add associate_maintaines' do
            associate_maintainer_users = @project.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
            associate_maintainer_users.should =~ [@associate_maintainer_user_1, @associate_maintainer_user_2]
          end
        end
      end
  
      context 'when update unsuccessfully' do
        before do
          @params_project = {:name => nil}  
        end
        
        context 'and when format html' do
          context 'when assciate_project_names blank' do
            before do
              post :update, :id => @project.id, :project => @params_project          
            end
            
            it 'should render edit template' do
              response.should render_template('edit')
            end
          end

          context 'when associate_projects present' do
            before do
              @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :denotations_count => 30, :relations_count => 40)
              @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 2, :denotations_count => 3, :relations_count => 4)
              @project_name = 'ansnet name'
            end
            
            describe 'before post' do
              it 'project pmdocs_count is 0' do
                @project.pmdocs_count.should eql(0)  
              end
              
              it 'project pmcdocs_count is 0' do
                @project.pmcdocs_count.should eql(0)  
              end
              
              it 'project denotations_count is 0' do
                @project.denotations_count.should eql(0)  
              end
              
              it 'project relations_count is 0' do
                @project.relations_count.should eql(0)  
              end
              
              it 'associate project should not have projects' do
                @associate_project_1.projects.should be_blank
              end       
                   
              it 'associate project should not have projects' do
                @associate_project_2.projects.should be_blank
              end            
            end
            
            describe 'after post' do
              before do
                post :update, :id => @project.id, :associate_projects => {:name => {'0' => @associate_project_1.name, '1' => @associate_project_2.name}}
                @project.reload
                @associate_project_1.reload
                @associate_project_2.reload
              end
              
              it 'associate project should have projects' do
                @associate_project_1.projects.should be_present
              end
              
              it 'associate project should equal created project' do
                @associate_project_1.projects.should include(Project.find_by_name(assigns[:project].name))
              end
              
              it 'associate project should have projects' do
                @associate_project_2.projects.should be_present
              end
              
              it 'associate project should equal created project' do
                @associate_project_2.projects.should include(Project.find_by_name(assigns[:project].name))
              end
              
              it 'should increment pmdocs_count by associate projects' do
                @project.pmdocs_count.should eql(@associate_project_1.pmdocs.count + @associate_project_2.pmdocs.count)
              end
               
              it 'should increment pmcdocs_count by associate projects' do
                @project.pmcdocs_count.should eql(@associate_project_1.pmcdocs.count + @associate_project_2.pmcdocs.count)
              end
              
              it 'should increment denotations_count by associate projects' do
                @project.denotations_count.should eql(@associate_project_1.denotations.count + @associate_project_2.denotations.count)
              end
              
              it 'should increment relations_count by associate projects' do
                @project.relations_count.should eql(@associate_project_1.relations.count + @associate_project_2.relations.count)
              end
               
              it 'should redirect to project_path' do
                response.should redirect_to(project_path(@project.name))
              end
            end
          end
        end
  
        context 'and when format json' do
          before do
            post :update, :id => @project.id, :format => 'json', :project => @params_project          
          end
          
          it 'should return response blank header' do
            response.body.should eql(assigns[:project].errors.to_json)
          end
          
          it 'should return resposne 422' do
            response.status.should eql(422)
          end
        end
      end
    end
  end
  
  describe 'destroy' do
    context 'when destroyable' do
      before do
        current_user = FactoryGirl.create(:user)
        current_user_stub(current_user)
        @project = FactoryGirl.create(:project, :name => 'project_name', :user => current_user)  
      end
      
      context 'format html' do
        before do
          delete :destroy, :id => @project.name   
        end
        
        it 'should redirect to projects_path' do
          response.should redirect_to projects_path
        end
      end
      
      context 'format html' do
        before do
          delete :destroy, :format => 'json', :id => @project.name   
        end
        
        it 'should return response blank header' do
          response.header.should be_blank
        end
      end
    end
  end
  
  describe 'search' do
    before do
      @project = FactoryGirl.create(:project, :name => 'project_name') 
      controller.stub(:get_project).and_return(@project)
      # PubMed
      @PubMed_sourceid_123_body_abc_serial_0 =   FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => '123',   :body => 'abc', :serial => 0)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PubMed_sourceid_123_body_abc_serial_0.id)
      @PubMed_sourceid_223_body_abc_serial_0 =   FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => '223',   :body => 'abc', :serial => 0)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PubMed_sourceid_223_body_abc_serial_0.id)
      @PubMed_sourceid_1234_body_bbcd_serial_1 =  FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => '1234',  :body => 'bbcd', :serial => 1)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PubMed_sourceid_1234_body_bbcd_serial_1.id)
      @project_PubMed_docs = @project.docs.where(:sourcedb => 'PubMed')

      # PMC
      @PMC_sourceid_123_body_abc_serial_0 =      FactoryGirl.create(:doc, :sourcedb => 'PMC',    :sourceid => '123',   :body => 'abc', :serial => 0)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PMC_sourceid_123_body_abc_serial_0.id)
      @PMC_sourceid_223_body_abc_serial_0 =      FactoryGirl.create(:doc, :sourcedb => 'PMC',    :sourceid => '223',   :body => 'abc', :serial => 0)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PMC_sourceid_223_body_abc_serial_0.id)
      @PMC_sourceid_123_body_abc_serial_1 =      FactoryGirl.create(:doc, :sourcedb => 'PMC',    :sourceid => '123',   :body => 'abc', :serial => 1)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PMC_sourceid_123_body_abc_serial_1.id)
      @PMC_sourceid_1234_body_bbcd_serial_0 =     FactoryGirl.create(:doc, :sourcedb => 'PMC',    :sourceid => '1234',  :body => 'bbcd', :serial => 0)
      FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @PMC_sourceid_1234_body_bbcd_serial_0.id)
      @project_PMC_docs =  @project.docs.pmcdocs

      # another projects
      @PubMed_another_project =   FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => '123',   :body => 'abc', :serial => 0)
      @PMC_another_project =  FactoryGirl.create(:doc, :sourcedb => 'PMC',    :sourceid => '1234',  :body => 'abcd', :serial => 0)
    end
    
    context 'when params[:doc] is PMC' do
      context 'when params[:sourceid] and params[:body] is blank' do
        before do
          get :search, :id => @project.name, :doc => 'PMC', :sourceid => nil, :body => nil
        end  
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
        
        it 'should have PubMed documents' do
          @project_PubMed_docs.should be_present
        end
        
        it 'should include all PubMed documents in project' do
          assigns[:pmdocs].should =~ @project_PubMed_docs
        end
        
        it 'should have PMC documents' do
          @project_PMC_docs.should be_present
        end
        
        it 'should include all PMC documents in project' do
          assigns[:pmcdocs].should =~ @project_PMC_docs
        end

        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
        
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end
      
      context 'when params[:sourceid] present' do
        before do
          get :search, :id => @project.name, :doc => 'PMC', :sourceid => 123, :body => nil
        end
        
        it '@pmc_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pmc_sourceid_value].should eql('123')
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
                
        it 'should include project.doc where sourceid = PMC and sourceid like params[:sourceid]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_123_body_abc_serial_0)
        end        
        
        it 'should not include project.doc where sourceid = PMC and sourceid is not like params[:sourceid]' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_223_body_abc_serial_0)
        end        
        
        it 'should include project.doc where sourceid = PMC and sourceid is like params[:sourceid]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_1234_body_bbcd_serial_0)
        end
        
        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
        
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end  
      
      context 'when params[:body] present' do
        before do
          get :search, :id => @project.name, :doc => 'PMC', :sourceid => nil, :body => 'abc'
        end
          
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be == params[:body]' do
          assigns[:pmc_body_value].should be_eql('abc')
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
              
        it 'should include project.doc where sourceid = PMC and body like params[:body]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_123_body_abc_serial_0)
        end        
        
        it 'should include project.doc where sourceid = PMC and body like params[:body]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_223_body_abc_serial_0)
        end        
        
        it 'should not include project.doc where sourceid = PMC and body is not like params[:body]' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_1234_body_bbcd_serial_0)
        end
        
        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
        
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end  
      
      context 'when params[:sourceid] nil, params[:body] present' do
        before do
          get :search, :id => @project.name, :doc => 'PMC', :sourceid => nil, :body => 'abc'
        end
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be == params[:body]' do
          assigns[:pmc_body_value].should be_eql('abc')
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
                
        it 'should include project.doc where sourceid = PMC and body like params[:body]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_123_body_abc_serial_0)
        end        
        
        it 'should include project.doc where sourceid = PMC and body like params[:body]' do
          assigns[:pmcdocs].should include(@PMC_sourceid_223_body_abc_serial_0)
        end        
        
        it 'should not include project.doc where sourceid = PMC and body is not like params[:body]' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_1234_body_bbcd_serial_0)
        end
        
        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
        
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end  
    end
    
    context 'when params[:doc] is PubMed' do
      context 'when params[:sourceid] and params[:body] is blank' do
        before do
          get :search, :id => @project.name, :doc => 'PubMed', :sourceid => nil, :body => nil
        end
         
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
               
        it 'should have PubMed documents' do
          @project_PubMed_docs.should be_present
        end
        
        it 'should include all PubMed documents in project' do
          assigns[:pmdocs].should =~ @project_PubMed_docs
        end
        
        it 'should have PMC documents' do
          @project_PMC_docs.should be_present
        end
        
        it 'should include all PMC documents in project' do
          assigns[:pmcdocs].should =~ @project_PMC_docs
        end

        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
        
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end
      
      context 'when params[:sourceid] present' do
        before do
          get :search, :id => @project.name, :doc => 'PubMed', :sourceid => 123
        end
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pm_sourceid_value].should be_eql('123')
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
                
        it 'should include project.doc where sourceid = PubMed and sourceid like params[:sourceid]' do
          assigns[:pmdocs].should include(@PubMed_sourceid_123_body_abc_serial_0)
        end
        
        it 'should include project.doc where sourceid = PubMed and sourceid like params[:sourceid]' do
          assigns[:pmdocs].should include(@PubMed_sourceid_1234_body_bbcd_serial_1)
        end
        
        it 'should not include project.doc where sourceid = PubMed and sourceid is not like params[:sourceid]' do
          assigns[:pmdocs].should_not include(@PubMed_sourceid_223_body_abc_serial_0)
        end

        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
                
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end
      
      context 'when params[:body] present' do
        before do
          get :search, :id => @project.name, :doc => 'PubMed', :sourceid => nil, :body => 'abc'
        end
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be == params[:body]' do
          assigns[:pm_body_value].should be_eql('abc')
        end
                
        it 'should include project.doc where sourceid = PubMed and body like params[:body]' do
          assigns[:pmdocs].should include(@PubMed_sourceid_123_body_abc_serial_0)
        end
        
        it 'should not include project.doc where sourceid = PubMed and body is not like params[:body]' do
          assigns[:pmdocs].should_not include(@PubMed_sourceid_1234_body_bbcd_serial_1)
        end
        
        it 'should include project.doc where sourceid = PubMed and body like params[:body]' do
          assigns[:pmdocs].should include(@PubMed_sourceid_223_body_abc_serial_0)
        end
        
        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end

        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end
      
      context 'when params[:sourceid] and params[:body] present' do
        before do
          get :search, :id => @project.name, :doc => 'PubMed', :sourceid => 123, :body => 'abc'
        end
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it '@pm_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pm_sourceid_value].should be_eql('123')
        end
        
        it '@pm_body_value shoould be == params[:body]' do
          assigns[:pm_body_value].should be_eql('abc')
        end
                
        it 'should include project.doc where sourceid = PubMed and body like params[:body]' do
          assigns[:pmdocs].should include(@PubMed_sourceid_123_body_abc_serial_0)
        end
        
        it 'should not include project.doc where sourceid = PubMed and body is not like params[:body]' do
          assigns[:pmdocs].should_not include(@PubMed_sourceid_1234_body_bbcd_serial_1)
        end
        
        it 'should not include project.doc where sourceid = PubMed and body is not like params[:sourceid]' do
          assigns[:pmdocs].should_not include(@PubMed_sourceid_223_body_abc_serial_0)
        end

        it 'should not include project.doc where serial is not 0' do
          assigns[:pmcdocs].should_not include(@PMC_sourceid_123_body_abc_serial_1)
        end
                
        it 'should not include another project PubMed document' do
          assigns[:pmdocs].should_not include(@PubMed_another_project)
        end
        
        it 'should not include another project PMC document' do
          assigns[:pmcdocs].should_not include(@PMC_another_project)
        end
      end
    end
  end
  
  describe 'updatable?' do
    before do
      @status_error = 'status error'
      controller.stub(:render_status_error).and_return(@status_error)
    end
    
    context 'when action edit' do
      before do
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
        @project = FactoryGirl.create(:project)
        controller.stub(:params).and_return({:action => 'edit', :id => @project.name})
      end
      
      context 'when updatable_for is true' do
        before do
          Project.any_instance.stub(:updatable_for?).and_return(true)
          @result = controller.updatable?
        end
    
        it 'should assign project' do
          assigns[:project].should eql(@project)
        end
        
        it 'should not raise render_status_error' do
          @result.should be_nil
        end
      end
      
      context 'when updatable_for is false' do
        before do
          Project.any_instance.stub(:updatable_for?).and_return(false)
          @result = controller.updatable?
        end
    
        it 'should assign project' do
          assigns[:project].should eql(@project)
        end
        
        it 'should raise render_status_error' do
          @result.should eql(@status_error)
        end
      end
    end
    
    context 'when action update' do
      before do
        @project_user = FactoryGirl.create(:user)
        @project = FactoryGirl.create(:project, :user => @project_user)
        @user_1 = FactoryGirl.create(:user, :username => 'User 1')
        @user_2 = FactoryGirl.create(:user, :username => 'User 2')
        controller.stub(:params).and_return({:action => 'update', :id => @project.id, :usernames => [@user_1.username, @user_2.username]})
        #Project.any_instance.stub(:build_associate_maintainers).and_return('build_associate_maintainers')
      end
      
      context 'when current_user = project.user' do
        before do
          current_user_stub(@project_user)
          @result = controller.updatable?
        end
          
        it 'should build associate_maintaines' do
          associate_maintainer_users = assigns[:project].associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
          associate_maintainer_users.should =~ [@user_1, @user_2]
        end
      end
      
      context 'when current_user != project.user' do
        before do
          current_user_stub(FactoryGirl.create(:user))
          @result = controller.updatable?
        end
          
        it 'should not build associate_maintaines' do
          assigns[:project].associate_maintainers.should be_blank
        end
      end
    end
  end
  
  describe 'destroyable?' do
    before do
      @project = FactoryGirl.create(:project)
      @render_status_error = 'render_status_error'
      controller.stub(:render_status_error).and_return(@render_status_error)
      controller.stub(:params).and_return({:id => @project.name})
      current_user_stub(FactoryGirl.create(:user))
    end
    
    context 'when destoryable_for true' do
      before do
        Project.any_instance.stub(:destroyable_for?).and_return(true)
        @result = controller.destroyable?
      end
      
      it 'should assign @project' do
        assigns[:project].should eql(@project)  
      end
      
      it '' do
        @result.should be_nil
      end
    end
    
    context 'when destoryable_for false' do
      before do
        Project.any_instance.stub(:destroyable_for?).and_return(false)
        @result = controller.destroyable?
      end
      
      it 'should assign @project' do
        assigns[:project].should eql(@project)  
      end
      
      it 'should raise render_status_error' do
        @result.should eql(@render_status_error)
      end
    end
  end
end
