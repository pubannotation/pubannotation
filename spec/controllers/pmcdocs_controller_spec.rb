# encoding: utf-8
require 'spec_helper'

describe PmcdocsController do
  describe 'index' do
    before do
      @user = FactoryGirl.create(:user)  
      @project = FactoryGirl.create(:project, :user => @user)
      @doc_pmc_0 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      @doc_pmc_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1)
    end
    
    context 'when params[:project_id] exists' do
      context 'and when project exists' do
        before do
          @projects = [@project]
          @project.docs << @doc_pmc_0
          @project.docs << @doc_pmc_1
          controller.stub(:get_project).and_return([@project, 'notice'])
        end
        
        context 'when format html' do
          before do
            get :index, :project_id => 1
          end
          
          it '@docs should include only which sourcedb == PMC and serial == 0' do
            assigns[:docs].should include(@doc_pmc_0)
            assigns[:docs].should_not include(@doc_pmc_1)
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
        
        context 'when format json' do
          before do
            get :index, :project_id => 1, :format => 'json'
          end
          
          it 'should render json' do
            response.body.should eql(assigns[:docs].to_json)
          end
        end
      end

      context 'and when project does not exists' do
        before do
          @notice = 'notice'
          controller.stub(:get_project).and_return([nil, @notice])
        end
        
        context 'when format html' do
          before do
            get :index, :project_id => 1
          end
          
          it '@docs should be nil' do
            assigns[:docs].should be_nil
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
          
          it 'should set get_project notice as flash[:notice]' do
            flash[:notice].should eql(@notice)
          end
        end

        context 'when format json' do
          before do
            get :index, :format => 'json', :project_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end
      end
    end
      
    context 'when params[:project_id] does not exists' do
      before do
        get :index
      end
      
      it '@docs should include only which sourcedb == PMC and serial == 0' do
        assigns[:docs].should include(@doc_pmc_0)
        assigns[:docs].should_not include(@doc_pmc_1)
      end
    end
  end
  
  describe 'show' do
    before do
      @get_project_notice = 'project notice'
      @get_divs_notice = 'project notice'
      @user = FactoryGirl.create(:user)  
      @project = FactoryGirl.create(:project, :user => @user)
      @div = FactoryGirl.create(:doc, :sourcedb => 'PMC')
      @divs = [@div]
    end
    
    context 'when params[:project_id] exists' do
      context 'and when project exists' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
        end
        
        context 'and when divs exists' do
          before do
            controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
            get :show, :project_id => 1, :id => 1
          end
          
          it 'should redirect to project_pmcdoc_divs_path' do
            response.should redirect_to(project_pmcdoc_divs_path(1, 1))
          end
        end

        context 'and when divs does not exists' do
          before do
            controller.stub(:get_divs).and_return([nil, @get_divs_notice])
          end
          
          context 'and when format html' do
            before do
              get :show, :project_id => 1, :id => 1
            end
            
            it 'should redirect to project_pmcdoc_divs_path' do
              response.should redirect_to(project_pmcdocs_path(1))
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'json', :project_id => 1, :id => 1
            end
            
            it 'should return status 422' do
              response.status.should eql(422)
            end
          end
        end
      end

      context 'and when project does not exists' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
          controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
          get :show, :project_id => 1, :id => 1
        end
        
        it 'should redirect to pmcdocs_path' do
          response.should redirect_to(pmcdocs_path)
        end
      end
    end
    
    context 'when params[:project_id] does not exists' do
      context 'and when divs exists' do
        before do
          controller.stub(:get_divs).and_return([@divs, @get_divs_notice])
        end
        
        context 'and when format html' do
          before do
            get :show, :id => 1
          end
          
          it 'should redirect to' do
            response.should redirect_to(pmcdoc_divs_path(1))
          end
        end
        
        context 'and when format json' do
          before do
            get :show, :id => 1, :format => 'json'
          end
          
          it 'should redirect to' do
            response.body.should eql(@divs.to_json)
          end
        end
      end
    end
  end
  
  describe 'create' do
    context 'when params[:project_id] exists' do
      context 'and when project exists' do
        before do
          @project = FactoryGirl.create(:project, :user => @user, :pmdocs_count => 0, :pmcdocs_count => 0)
          @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
          @associate_project_1_pmdocs_count = 1
          @associate_project_1_pmdocs_count.times do
            @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed') 
          end
          @associate_project_1_pmcdocs_count = 2
          @associate_project_1_pmcdocs_count.times do
            @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0) 
          end     
          @associate_project_1.reload
                
          @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
          @associate_project_2_pmdocs_count = 3
          @associate_project_2_pmdocs_count.times do
            @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed') 
          end
          @associate_project_2_pmcdocs_count = 4
          @associate_project_2_pmcdocs_count.times do
            @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0) 
          end     
          @associate_project_2.reload
      
          @project.associate_projects << @associate_project_1
          @project.associate_projects << @associate_project_2
          controller.stub(:get_project).and_return([@associate_project_1, 'notice'])
          @project.reload
        end
        
        context 'and when divs found by sourcedb and sourceid' do
          before do
            @sourcedb = 'PMC'
            @sourceid = 'sourceid'
            @div = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid, :serial => 0)            
          end
          
          describe 'counters before create' do
            it 'should increment only project.pmdocs_count' do
              @project.pmcdocs_count.should eql(6)
              @project.pmdocs_count.should eql(4)
            end
            
            it 'should incremant only associate project.pmdocs_count' do
              @associate_project_1.pmcdocs_count.should eql(2)
              @associate_project_1.pmdocs_count.should eql(1)
            end
            
            it 'should incremant only associate_project.pmdocs_count' do
              @associate_project_2.pmcdocs_count.should eql(4)
              @associate_project_2.pmdocs_count.should eql(3)
            end
          end
          
          context 'and when project.docs does not include divs.first' do
            context 'and when format html' do
              before do
                post :create, :project_id => @associate_project_1.id, :pmcids => @sourceid
              end
              
              it 'should redirect_to project_pmcdocs_path' do
                response.should redirect_to(project_path(@associate_project_1.name, :accordion_id => 2))
              end
              
              it 'should incremant only associate project.pmdocs_count' do
                @associate_project_1.reload
                @associate_project_1.pmcdocs_count.should eql(3)
                @associate_project_1.pmdocs_count.should eql(1)
              end
              
              it 'should incremant only associate_project.pmdocs_count' do
                @associate_project_2.reload
                @associate_project_2.pmcdocs_count.should eql(4)
                @associate_project_2.pmdocs_count.should eql(3)
              end
              
              it 'should increment only project.pmdocs_count' do
                @project.reload
                @project.pmcdocs_count.should eql(7)
                @project.pmdocs_count.should eql(4)
              end
            end

            context 'and when format json' do
              before do
                post :create, :format => 'json', :project_id => FactoryGirl.create(:project).id, :pmcids => @sourceid
              end
              
              it 'should return status 201' do
                response.status.should eql(201)
              end
              
              it 'should return location' do
                response.location.should eql(project_path(@associate_project_1.name, :accordion_id => 2))
              end
            end
          end
        end
        
        context 'and when divs not found by sourcedb and sourceid' do
          context 'and when divs returned by gen_pmcdoc' do
            before do
              @div = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'sourceid', :serial => 0)
              controller.stub(:gen_pmcdoc).and_return([[@div], 'message'])            
              post :create, :project_id => @associate_project_1.name, :pmcids => 'abcd'
            end

            it 'should redirect_to project_pmcdocs_path' do
              response.should redirect_to(project_path(@associate_project_1.name, :accordion_id => 2))
            end
         
            it 'should incremant only associate project.pmdocs_count' do
              @associate_project_1.reload
              @associate_project_1.pmcdocs_count.should eql(3)
              @associate_project_1.pmdocs_count.should eql(1)
            end
            
            it 'should incremant only associate_project.pmdocs_count' do
              @associate_project_2.reload
              @associate_project_2.pmcdocs_count.should eql(4)
              @associate_project_2.pmdocs_count.should eql(3)
            end
            
            it 'should increment only project.pmdocs_count' do
              @project.reload
              @project.pmcdocs_count.should eql(7)
              @project.pmdocs_count.should eql(4)
            end          
          end

          context 'and when divs does not returned by gen_pmcdoc' do
            before do
              @div = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid')
              controller.stub(:gen_pmcdoc).and_return([nil, 'message'])            
              post :create, :project_id => 1, :pmcids => 'abcd,cdef'
            end
            
            it 'should redirect to project_pmcdocs_path' do
              response.should redirect_to(project_path(@associate_project_1.name, :accordion_id => 2))
            end
          end
        end
      end
    end

    context 'when params[:project_id] does not exists' do
      context 'and when format html' do
        before do
          post :create
        end
        
        it 'should redirect to home_path' do
          response.should redirect_to home_path
        end
      end

      context 'and when format html' do
        before do
          post :create, :format => 'json'
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
  end
  
  describe 'search' do
    context 'without pagination' do
      before do
        @pubmed = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 234)
        @selial_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1, :sourceid => 123)
        @sourceid_123 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 123)
        @sourceid_1234 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1234)
        @sourceid_1123 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1123)
        @sourceid_234 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 234)
      end
      
      context 'when params[:sourceid] and params[:body] is nil' do
        before do
          get :search
        end  
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be nil' do
          assigns[:pmc_body_value].should be_nil
        end
                
        it 'should not include sourcedb is not PMC' do
          assigns[:docs].should_not include(@pubmed)
        end
        
        it 'should not include soucedb is PMC and serial is not 0' do
          assigns[:docs].should_not include(@selial_1)
        end
        
        it 'should include soucedb is PMC and serial is 0' do
          assigns[:docs].should include(@sourceid_123)
        end
  
        it 'should include soucedb is PMC and serial is 0' do
          assigns[:docs].should include(@sourceid_1234)
        end
  
        it 'should include soucedb is PMC and serial is 0' do
          assigns[:docs].should include(@sourceid_1123)
        end
  
        it 'should include soucedb is PMC and serial is 0' do
          assigns[:docs].should include(@sourceid_234)
        end
      end
      
      context 'when params[:sourceid] present' do
        before do
          get :search, :sourceid => '123'
        end
        
        it '@pmc_sourceid_value should be == parans[:sourceid]' do
          assigns[:pmc_sourceid_value].should be_eql('123')
        end
        
        it '@pmc_body_value should be nil' do
          assigns[:pmc_body_value].should be_nil
        end
        
        it 'should not include sourcedb is not PMC' do
          assigns[:docs].should_not include(@pubmed)
        end
        
        it 'should not include serial is not 0' do
          assigns[:docs].should_not include(@selial_1)
        end
        
        it 'should include sourceid include 123' do
          assigns[:docs].should include(@sourceid_123)
        end
  
        it 'should include sourceid include 123' do
          assigns[:docs].should include(@sourceid_1234)
        end
  
        it 'should include sourceid include 123' do
          assigns[:docs].should include(@sourceid_1123)
        end
  
        it 'should not include sourceid not include 123' do
          assigns[:docs].should_not include(@sourceid_234)
        end
      end
      
      context 'when params[:body] present' do
        before do
          @sourceid_123_test = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 123, :body => 'test')
          @sourceid_1234_test = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1234, :body => 'testmatch')
          @sourceid_234_test = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 234, :body => 'matchtest')
          @sourceid_123_est = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 123, :body => 'est')
          get :search, :body => 'test'
        end
        
        it '@pmc_sourceid_value shoould be nil' do
          assigns[:pmc_sourceid_value].should be_nil
        end
        
        it '@pmc_body_value shoould be == params[:body]' do
          assigns[:pmc_body_value].should be_eql('test')
        end
        
        it 'should include  body contains body' do
          assigns[:docs].should include(@sourceid_123_test)
        end
        
        it 'should include body contains body' do
          assigns[:docs].should include(@sourceid_1234_test)
        end
        
        it 'should include body contains body' do
          assigns[:docs].should include(@sourceid_234_test)
        end
        
        it 'should include body contains body' do
          assigns[:docs].should_not include(@sourceid_123_est)
        end
      end
      
      context 'when params[:sourceid] and params[:body] present' do
        before do
          @sourceid_1_body_test = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1, :body => 'test')
          @sourceid_1_body_test_and = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1, :body => 'testand')
          @sourceid_1_body_nil = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 1, :body => nil)
          @sourceid_2_body_test = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 2, :body => 'test')
          get :search, :sourceid => 1, :body => 'test'
        end
        
        it '@pmc_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pmc_sourceid_value].should be_eql('1')
        end
        
        it '@pmc_body_value shoould be == params[:body]' do
          assigns[:pmc_body_value].should be_eql('test')
        end
        
        it 'should include sourceid and body matches' do
          assigns[:docs].should include(@sourceid_1_body_test)
        end
        
        it 'should include sourceid and body matches' do
          assigns[:docs].should include(@sourceid_1_body_test_and)
        end
        
        it 'should not include body does not match' do
          assigns[:docs].should_not include(@sourceid_1_body_nil)
        end
        
        it 'should not include sourceid does not match' do
          assigns[:docs].should_not include(@sourceid_2_body_test)
        end
      end
    end
    
    context 'with pagination' do
      before do
        @first_page = FactoryGirl.create(:doc, :id => 1, :sourcedb => 'PMC', :serial => 0, :sourceid => 1)
        i = 2
        WillPaginate.per_page.times do
          FactoryGirl.create(:doc, :id => i, :sourcedb => 'PMC', :serial => 0, :sourceid => 1)
          i += 1
        end
        @next_page = FactoryGirl.create(:doc, :id => i, :sourcedb => 'PMC', :serial => 0, :sourceid => 1)
      end
      
      context 'when page = 1' do
        before do
          get :search, :sourceid => 1, :page => 1
        end
        
        it '@docs should include first page record' do
          assigns[:docs].should include(@first_page)        
        end
        
        it '@docs should not include second page record' do
          assigns[:docs].should_not include(@next_page)        
        end
      end
      
      context 'when page = 2' do
        before do
          get :search, :sourceid => 1, :page => 2
        end
        
        it '@docs should not include first page record' do
          assigns[:docs].should_not include(@first_page)        
        end
        
        it '@docs should include second page record' do
          assigns[:docs].should include(@next_page)        
        end
      end
    end
  end
  
  describe 'destroy' do
    context 'when params[:project_id] does not present' do
      before do
        @div = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'sourceid')
        @div_2 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'sourceid')
        @div_3 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'sourceid_different')
      end
      
      context 'when divs blank' do
        before do
          delete :destroy, :project_id => nil, :id => 'id'
        end
        
        it 'docs where sourcedb = PMC size should be 3' do
          Doc.where(:sourcedb => 'PMC').should =~ [@div, @div_2, @div_3]
        end
        
        it 'should redirect_to pmcdocs path' do
          response.should redirect_to(pmcdocs_path)
        end
        
        it 'set project does not document_removed_from_pubannotation as flash[:notice]' do
          flash[:notice].should eql(I18n.t('controllers.pmcdocs.destroy.document_does_not_exist_in_pubannotation', :id => 'id'))
        end
      end
      
      context 'when divs present' do
        it 'docs where sourcedb = PMC size should be 3' do
          Doc.where(:sourcedb => 'PMC').should =~ [@div, @div_2, @div_3]
        end
                
        describe 'delete' do
          before do
            delete :destroy, :project_id => nil, :id => @div.sourceid
          end
          
          it 'doc where sourcedb = PMC and sourceid is params[:id] should be deleted' do
            Doc.where(:sourcedb => 'PMC').should =~ [@div_3]
          end
        end
      end
    end
    
    context 'when params[:project_id] present' do
      context 'when project present' do
        before do
          @project = FactoryGirl.create(:project, :pmdocs_count => 2, :pmcdocs_count => 1)
          @not_div = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 'sourceid')
          FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @not_div.id)
        end
          
        context 'when divs present' do
          before do
            @div = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'sourceid', :serial => 0)
            FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @div.id)
          end
          
          it 'project.doc should include @div, @not_div' do
            @project.docs.should =~ [@div, @not_div]  
          end
          
          describe 'delete' do
            before do
              delete :destroy, :project_id => @project.name, :id => @div.sourceid
            end
            
            it 'div should deleted from project.docs' do
              @project.docs.should =~ [@not_div]
            end
            
            it 'should redirect_to project path' do
              response.should redirect_to(project_path(@project.name, :accordion_id => 2))
            end
            
            it 'set document removed from annotation set as flash[:notice]' do
              flash[:notice].should eql(I18n.t('controllers.pmcdocs.destroy.document_removed_from_annotation_set', :sourcedb => @div.sourcedb, :sourceid => @div.sourceid,:project_name => @project.name))
            end
          
            it 'should decrement only project.pmdocs_count' do
              @project.pmcdocs_count.should eql(1)
              @project.reload
              @project.pmcdocs_count.should eql(0)
              @project.pmdocs_count.should eql(2)
            end
          end
        end

        context 'when divs does not present' do
          before do
            delete :destroy, :project_id => @project.name, :id => 1
          end
          
          it 'should redirect_to project path' do
            response.should redirect_to(project_path(@project.name, :accordion_id => 2))
          end
          
          it 'should set project does not include_document as flash[:notice]' do
            flash[:notice].should eql(I18n.t('controllers.pmcdocs.destroy.project_does_not_include_document', :project_name => @project.name, :sourcedb => 1))
          end
        end
      end

      context 'when project blank' do
        before do
          @project = FactoryGirl.create(:project)
          @not_div = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => 'sourceid')
          FactoryGirl.create(:docs_project, :project_id => @project.id, :doc_id => @not_div.id)
          @project_id = 'invalid project name'
          delete :destroy, :project_id => @project_id, :id => 1
        end
        
        it 'should redirect_to pmcdocs path' do
          response.should redirect_to(pmcdocs_path)
        end
        
        it 'set project does not exist_in_pubannotation as flash[:notice]' do
          flash[:notice].should eql(I18n.t('controllers.pmcdocs.destroy.project_does_not_exist_in_pubannotation', :project_id => @project_id))
        end
      end
    end
  end
  
  describe 'sql' do
    before do
      @sql_find = ['Denotation sql_find']      
    end
    
    context 'when params[:project_id] present' do
      before do
        Doc.stub(:sql_find).and_return(@sql_find)
        @project = FactoryGirl.create(:project)
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
      end
      
      context 'when project present' do
        before do
          get :sql, :project_id => @project.name, :sql => 'select * from docs;'
        end
        
        it 'should assign project_pmdocs_sql_path as @search_path' do
          assigns[:search_path] = project_pmdocs_sql_path
        end
        
        it 'should assign Doc.sql_find as @denotations' do
          assigns[:docs].should eql(@sql_find)
        end
      end

      context 'when project blank' do
        before do
          get :sql, :project_id => 'invalid', :sql => 'select * from docs;'
        end
        
        it 'should assign project_pmdocs_sql_path as @search_path' do
          assigns[:search_path] = project_pmdocs_sql_path
        end
        
        it '@redirected should be true' do
          assigns[:redirected].should be_true
        end
        
        it 'should redirect_to project_pmdocs_sql_path' do
          response.should redirect_to(sql_pmcdocs_path)
        end
      end
    end
    
    context 'when invalid SQL' do
      before do
        get :sql, :sql => 'select - docss;'
      end
      
      it 'should assign flash[:notice]' do
        flash[:notice].should be_present
      end
    end
  end  
end