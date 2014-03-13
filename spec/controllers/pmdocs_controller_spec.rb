# encoding: utf-8
require 'spec_helper'

describe PmdocsController do
  describe 'index' do
    context 'when params[:project_id] exists' do
      context 'and when @ansnet exists' do
        before do
          @project = FactoryGirl.create(:project)
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0)
          @project.docs << @doc
          controller.stub(:get_project).and_return([@project, 'notice'])
        end
        
        context 'and when format html' do
          before do
            get :index, :project_id => @project.id
          end
          
          it 'should render template' do
            flash[:notice].should be_nil
          end
          
          it 'should render template' do
            response.should render_template('index')
          end
        end
        
        context 'and when format json' do
          before do
            get :index, :format => 'json', :project_id => @project.id
          end
          
          it 'should render json' do
            response.body.should eql(@project.docs.to_json)
          end
        end
      end

      context 'and when @ansnet does not exists' do
        before do
          @notice = 'notice'
          controller.stub(:get_project).and_return([nil, @notice])
        end
        
        context 'and when format html' do
          before do
            get :index, :project_id => 1
          end
          
          it 'should render template' do
            should render_template('index')
          end

          it 'should set notice as flash[:notice]' do
            flash[:notice].should eql(@notice)
          end
        end
      end
    end

    context 'when params[:project_id] exists' do
      before do
        get :index
      end      
      
      it 'should render template' do
        should render_template('index')
      end
    end
  end
  
  describe 'show' do
    context 'when params[:project_id] exists' do
      context 'and when @ansnet exists' do
        context 'and when get_doc returns @doc' do
          before do
            @project = FactoryGirl.create(:project)
            @doc = FactoryGirl.create(:doc, :body => 'doc body')
            controller.stub(:get_project).and_return([@project, ''])
            @get_doc_notice = 'get doc notice'
            controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
          end
          
          context 'and when format html' do
            before do
              get :show, :id => @doc.id, :project_id => @project.id, :encoding => 'ascii'
            end
            
            it 'should render template' do
              response.should render_template('docs/show')
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'json', :id => @doc.id, :project_id => @project.id
            end
            
            it 'should render json' do
              response.body.should eql({:pmdoc_id => @doc.id.to_s, :text => @doc.body}.to_json)
            end
          end
          
          context 'and when format json' do
            before do
              get :show, :format => 'txt', :id => @doc.id, :project_id => @project.id
            end
            
            it 'should render text' do
              response.body.should eql(@doc.body)
            end
          end
        end
      end

      context 'and when @ansnet does not exists' do
        before do
          controller.stub(:get_project).and_return([nil, ''])
        end
        
        context 'and when format html' do
          before do
            get :show, :id => 1, :project_id => 1
          end
          
          it 'should redirect to pmdocs_path' do
            response.should redirect_to(pmdocs_path)
          end
        end      
        
        context 'and when format json' do
          before do
            get :show, :format => 'json', :id => 1, :project_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end      
        
        context 'and when format json' do
          before do
            get :show, :format => 'txt', :id => 1, :project_id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end      
      end
    end
    
    context 'when params[:project_id] does not exists' do
      before do
        get :show, :id => 1
      end      

      it 'should redirect to pmdocs_path' do
        response.should redirect_to(pmdocs_path)
      end
    end
  end
  
  describe 'spans_index' do
    before do
      @project = FactoryGirl.create(:project)
      controller.stub(:get_project).and_return([@project, nil])
      @doc = FactoryGirl.create(:doc, :sourceid => '12345', :sourcedb => 'PubMed')
      controller.stub(:get_doc).and_return([@doc, nil])
    end
    
    context 'when project_id present' do
      before do
        @denotation_1 = {:span => 'span1'}
        @denotation_2 = {:span => 'span2'}
        @denotations = [@denotation_1, @denotation_1, @denotation_2]
        controller.stub(:get_annotations).and_return({:denotations => @denotations})
        get :spans_index, :project_id => @project.name, :id => @doc.sourceid
      end
      
      it 'should assign @project' do
        assigns[:project].should eql(@project)  
      end
      
      it 'should assign @doc' do
        assigns[:doc].should eql(@doc)  
      end
      
      it 'should assign unique denotation hashes as @denotations' do
        assigns[:denotations].should =~ @denotation_1.map{|key, value| {key.to_s => value}} + @denotation_2.map{|key, value| {key.to_s => value}}
      end
      
      it 'should render template' do
        response.should render_template('docs/spans_index')
      end
    end
    
    context 'when project_id blank' do
      before do
        @denotation = FactoryGirl.create(:denotation)
        @doc.denotations << @denotation
        get :spans_index, :id => @doc.sourceid
      end
      
      it 'should assign @doc' do
        assigns[:doc].should eql(@doc)  
      end
      
      it 'should assign @denotations' do
        assigns[:denotations].should eql([{"id" => @denotation.hid, "span" => {"begin" => @denotation.begin, "end" => @denotation.end}, "obj" => @denotation.obj}])  
      end
      
      it 'should render template' do
        response.should render_template('docs/spans_index')
      end
    end
  end
  
  describe 'spans' do
    before do
      @body = 'doc body'
      @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
      @project = 'project'
      @project_1 = FactoryGirl.create(:project)
      @projects = [@project_1]
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
          get :spans, :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
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
    
    context 'when params[:project_id] blank' do
      before do
        @project_denotation = 'project denotations'
        @project_denotations = {:denotations => @project_denotation}
        controller.stub(:get_annotations).and_return(@project_denotations)
        get :spans, :id => @doc.sourceid, :begin => 1, :end => 5
      end
      
      it 'should not assign @project' do
        assigns[:project].should be_nil
      end
      
      it 'should assign @projects' do
        assigns[:projects].should eql(@projects)
      end
      
      it 'should assign @project_denotations' do
        assigns[:project_denotations].should eql([{'project' => @project_1, 'denotations' => @project_denotation}])
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
      controller.stub(:get_annotations_for_json).and_return(@annotations)
    end
    
    context 'when params[:project_id] present' do
      before do
        get :annotations, :project_id => @project.name, :id => @doc.id, :begin => 1, :end => 10
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
      
      it 'should assign @relations' do
        assigns[:relations].should eql(@annotations[:relations])
      end
      
      it 'should assign @modifications' do
        assigns[:modifications].should eql(@annotations[:modifications])
      end
    end
    
    
    context 'when params[:project_id] blank' do
      before do
        get :annotations, :id => @doc.id, :begin => 1, :end => 10
      end
      
      it 'should not assign @project' do
        assigns[:project].should be_nil
      end
      
      it 'should assign @doc' do
        assigns[:doc].should eql(@doc)
      end
    end
    
    context 'when format json' do
      before do
        get :annotations, :format => :json, :id => @doc.id, :begin => 1, :end => 10
      end
      
      it 'sould render json' do
        response.body.should eql(@annotations.to_json)
      end      
    end
  end
  
  describe 'create' do
    context 'when params[:project_id] exists' do
      context 'and when format html' do
        before do
          post :create, :pmids => 'pmids'
        end
        
        it 'should redirect to home_path' do
          response.should redirect_to(home_path)
        end
      end

      context 'and when format html' do
        before do
          post :create, :format => 'json', :pmids => 'pmids'
        end
        
        it 'should return status 422' do
          response.status.should eql(422)
        end
      end
    end
    
    context 'when params[:project_id] exists' do
      context 'and when project exists' do
        before do
          @sourceid = 'sourceid'
          # project
          @project = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
          @project_2 = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 0)
          @project_3 = FactoryGirl.create(:project, :pmdocs_count => 2, :pmcdocs_count => 0)
          # project.projects
          @project_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_1, :associate_project => @project)
          @project_project_2 = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 0)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_2, :associate_project => @project)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_2, :associate_project => @project_2)
          # project.projects.projects
          @project_project_project_1 = FactoryGirl.create(:project, :pmdocs_count => 3, :pmcdocs_count => 0)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_project_1, :associate_project => @project_project_1)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_project_1, :associate_project => @project_project_2)
          FactoryGirl.create(:associate_projects_project, :project => @project_project_project_1, :associate_project => @project_3)
          # force to associate projects
          @project.reload
          controller.stub(:get_project).and_return([@project, 'notice'])        
        end
        
        context 'and when doc found by sourcedb and sourceid and serial' do
          before do
            @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PubMed', :serial => 0)
          end
          
          context 'and when format html' do
            before do
              post :create, :project_id => @project.id, :pmids => @sourceid
            end
            
            it 'should redirect to project_pmdocs_path' do
              response.should redirect_to(project_path(@project.name, :accordion_id => 1))
            end
            
            it 'should increment only project.pmdocs_count' do
              @project.reload
              @project.pmdocs_count.should eql(1)
              @project.pmcdocs_count.should eql(0)
            end
            
            it 'should incremant only associate project.pmdocs_count' do
              @project_project_1.reload
              @project_project_1.pmdocs_count.should eql(1)
              @project_project_1.pmcdocs_count.should eql(0)
            end
            
            it 'should incremant only associate project.pmdocs_count' do
              @project_project_2.reload
              @project_project_2.pmdocs_count.should eql(2)
              @project_project_2.pmcdocs_count.should eql(0)
            end
          end
          
          context 'and when format json' do
            before do
              post :create, :format => 'json', :project_id => 1, :pmids => @sourceid
            end
            
            it 'should return status created' do
              response.status.should eql(201)
            end
            
            it 'should return location' do
              response.location.should eql(project_path(@project.name, :accordion_id => 1))
            end
          end
        end
        
        context 'and when doc not found by sourcedb and sourceid and serial' do
          context 'and when gem_pmdoc returns doc' do
            before do
              @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PM', :serial => 0)
              PMDoc.stub(:generate).and_return(@doc)
              post :create, :project_id => 1, :pmids => @sourceid
            end
            
            it 'should redirect to project_pmdocs_path' do
              response.should redirect_to(project_path(@project.name, :accordion_id => 1))
            end
          end

          context 'and when gem_pmdoc does not returns doc' do
            before do
              @doc = FactoryGirl.create(:doc, :sourceid => @sourceid, :sourcedb => 'PM', :serial => 0)
              PMDoc.stub(:generate).and_return(nil)
              post :create, :project_id => 1, :pmids => @sourceid
            end
            
            it 'should redirect to project_pmdocs_path' do
              response.should redirect_to(project_path(@project.name, :accordion_id => 1))
            end
          end
        end
      end
    end
  end
  
  describe 'update' do
    context 'when params[:project_id] exists' do
      context 'and when project found by name' do
        context 'and when doc found by sourcedb and sourceid' do
          context 'and when doc.projects does not include project' do
            before do
              @project = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
              @id = 'sourceid'
              @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
              @associate_project_1_pmcdocs_count = 2
              @i = 1
              @associate_project_1_pmcdocs_count.times do
                @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
                @i += 1 
              end     
              @associate_project_1.reload
              
              @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
              @associate_project_2_pmdocs_count = 3
              @associate_project_2_pmdocs_count.times do
                @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i)
                @i += 1 
              end
              @associate_project_2_pmcdocs_count = 4
              @associate_project_2_pmcdocs_count.times do
                @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
                @i += 1 
              end     
              @associate_project_2.reload
                            
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
              @associate_project_1.reload
              @project.associate_projects << @associate_project_1
              @project.associate_projects << @associate_project_2
            end
            
            describe 'counters before update' do
              it 'project counters should equal associate project counters' do
                @project.reload
                @project.pmdocs_count.should eql(@associate_project_2_pmdocs_count * 2 )
                @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
              end
              
              it 'associate project counters same as before statements' do
                @associate_project_1.reload
                @associate_project_1.pmdocs_count.should eql(0)
                @associate_project_1.pmcdocs_count.should eql(2)
              end
              
              it 'associate project counters same as before statements' do
                @associate_project_2.reload
                @associate_project_2.pmdocs_count.should eql(3)
                @associate_project_2.pmcdocs_count.should eql(4)
              end
            end
            
            context 'and when format html' do
              before do
                post :update, :project_id => @associate_project_1.name, :id => @id
              end
              
              it 'should redirect to project_pmdocs_path' do
                response.should redirect_to(project_path(@associate_project_1.name, :accordion_id => 1))
              end
            
              it 'should increment pmdocs_counter' do
                @project.reload
                @project.pmdocs_count.should eql((@associate_project_2_pmdocs_count * 2 ) + 1)
                @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
              end
              
              it 'should increment pmdocs_counter' do
                @associate_project_1.reload
                @associate_project_1.pmdocs_count.should eql(1)
                @associate_project_1.pmcdocs_count.should eql(2)
              end
              
              it 'should not increment counters' do
                @associate_project_2.reload
                @associate_project_2.pmdocs_count.should eql(3)
                @associate_project_2.pmcdocs_count.should eql(4)
              end
            end
            
            context 'and when format json' do
              before do
                post :update, :format => 'json', :project_id => @associate_project_1.name, :id => @id
              end
              
              it 'return blank header' do
                response.header.should be_blank
              end
            end
          end
        end

        context 'and when doc not found by sourcedb and sourceid' do
          context 'and when PMDoc.generate return doc' do
            before do
              @project = FactoryGirl.create(:project, :name => 'project name', :pmdocs_count => 0, :pmcdocs_count => 0)
              @id = 'sourceid2'
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
              @i = 1
              @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
              @associate_project_1_pmcdocs_count = 2
              @associate_project_1_pmcdocs_count.times do
                @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i)
                @i += 1 
              end     
              @associate_project_1.reload
              @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
              @associate_project_2_pmdocs_count = 3
              @associate_project_2_pmdocs_count.times do
                @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i) 
                @i += 1 
              end
              @associate_project_2_pmcdocs_count = 4
              @associate_project_2_pmcdocs_count.times do
                @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
                @i += 1 
              end     
              @associate_project_2.reload
              @project.associate_projects << @associate_project_1
              @project.associate_projects << @associate_project_2
              PMDoc.stub(:generate).and_return(@doc)
            end
            
            describe 'counters before update' do
              it 'project counters should equal associate project counters' do
                @project.reload
                @project.pmdocs_count.should eql(@associate_project_2_pmdocs_count * 2 )
                @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)                
              end
              
              it 'associate project counters same as before statements' do
                @associate_project_1.reload
                @associate_project_1.pmdocs_count.should eql(0)
                @associate_project_1.pmcdocs_count.should eql(2)
              end
              
              it 'associate project counters same as before statements' do
                @associate_project_2.reload
                @associate_project_2.pmdocs_count.should eql(3)
                @associate_project_2.pmcdocs_count.should eql(4)
              end
            end
                        
            describe 'after post' do
              before do
                post :update, :project_id => @associate_project_1.name, :id => 'invalidid'
              end

              it 'should redirect to project_pmdocs_path' do
                response.should redirect_to(project_path(@associate_project_1.name, :accordion_id => 1))
              end
              
              it 'should set flash[:notice]' do
                flash[:notice].should eql("The document, #{@doc.sourcedb}:#{@doc.sourceid}, was created in the annotation set, #{@associate_project_1.name}.")
              end
            
              it 'should increment pmdocs_count' do
                @project.reload
                @project.pmdocs_count.should eql((@associate_project_2_pmdocs_count * 2 ) + 1)
                @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
              end
              
              it 'should increment pmdocs_count' do
                @associate_project_1.reload
                @associate_project_1.pmdocs_count.should eql(1)
                @associate_project_1.pmcdocs_count.should eql(2)
              end
              
              it 'should not increment counters' do
                @associate_project_2.reload
                @associate_project_2.pmdocs_count.should eql(3)
                @associate_project_2.pmcdocs_count.should eql(4)
              end
            end
          end
          
          context 'and when PMDoc.generate does not return doc' do
            before do
              @project = FactoryGirl.create(:project)
              @id = 'sourceid'
              PMDoc.stub(:generate).and_return(nil)
              post :update, :project_id => @project.name, :id => @id
            end

            it 'should redirect to project_pmdocs_path' do
              response.should redirect_to(project_path(@project.name, :accordion_id => 1))
            end
            
            it 'should set flash[:notice]' do
              flash[:notice].should eql("The document, PubMed:#{@id}, could not be created.")
            end
          end
        end
      end

      context 'and when project not found by name' do
        before do
          @project = FactoryGirl.create(:project)
          @id = 'sourceid'
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          @project_id = 'project id'
          post :update, :project_id => @project_id, :id => @id
        end
        
        it 'should redirect to pmdocs_path' do
          response.should redirect_to(pmdocs_path)
        end

        it 'should set flash[:notice]' do
          flash[:notice].should eql("The annotation set, #{@project_id}, does not exist.")
        end
      end
    end

    context 'when params[:project_id] does not exists' do
      context 'and when PMDoc.generate returns doc' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          PMDoc.stub(:generate).and_return(@doc)
          @id = 1
          post :update, :id => 1
        end      
        
        it 'should redirect to pmdocs_path' do
          response.should redirect_to(pmdocs_path)  
        end
        
        it 'should set flash[:notice]' do
          flash[:notice].should eql("The document, PubMed:#{@id}, was successfuly created.")
        end
      end

      context 'and when PMDoc.generate does not returns doc' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id)
          PMDoc.stub(:generate).and_return(nil)
          @id = 1
        end      
        
        context 'and when format html' do
          before do
            post :update, :id => 1
          end
          
          it 'should redirect to pmdocs_path' do
            response.should redirect_to(pmdocs_path)  
          end
          
          it 'should set flash[:notice]' do
            flash[:notice].should eql("The document, PubMed:#{@id}, could not be created.")
          end
        end
        
        context 'and when format json' do
          before do
            post :update, :format => 'json', :id => 1
          end
          
          it 'should return status 422' do
            response.status.should eql(422) 
          end
        end
      end
    end
  end
  
  describe 'destroy' do
    before do
      @id = 'sourceid'
    end
    
    context 'when params[:project_id] does not exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id, :serial => 0)  
        delete :destroy, :id => @id
      end
      
      it 'should destroy doc' do
        Doc.where(:id => @doc.id).should be_blank
      end
      
      it 'should redirect to pmdocs_path' do
        response.should redirect_to(pmdocs_path)
      end
      
      it 'should not set flash[:notice]' do
        flash[:notice].should be_nil
      end
    end
    
    context 'when params[:project_id] exists' do
      before do
        @project_id = 'project id'
      end
      
      context 'when project found by nanme' do
        before do
          @project = FactoryGirl.create(:project, :name => @project_id, :pmcdocs_count => 1, :pmdocs_count => 1)  
        end
        
        context 'when project found by name' do
          context 'when doc found by sourcedb and source id' do
            before do
              @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @id, :serial => 0)  
            end
            
            context 'when doc.projects include project' do
              before do
                @doc.projects << @project
              end
              
              context 'when format html' do
                before do
                  delete :destroy, :project_id => @project_id, :id => @id
                end
                
                it 'should redirect to project_pmdocs_path(project.name)' do
                  response.should redirect_to(project_path(@project.name, :accordion_id => 1))
                end
                
                it 'should set flash[:notice]' do
                  flash[:notice].should eql("The document, #{@doc.sourcedb}:#{@doc.sourceid}, was removed from the annotation set, #{@project.name}.")
                end
                
                it 'should decrement project.pmdocs_count' do
                  @project.pmdocs_count.should eql(1)
                  @project.reload
                  @project.pmdocs_count.should eql(0)
                end
              end
              
              context 'when format json' do
                before do
                  delete :destroy, :format => 'json', :project_id => @project_id, :id => @id
                end
                
                it 'should return blank header' do
                  response.header.should be_blank
                end
              end
            end
            
            context 'when doc.projects does not include project' do
              before do
                delete :destroy, :project_id => @project_id, :id => @id
              end
              
              it 'should redirect to project_pmdocs_path(project.name)' do
                response.should redirect_to(project_path(@project.name, :accordion_id => 1))
              end
              
              it 'should set flash[:notice]' do
                flash[:notice].should eql("the annotation set, #{@project.name} does not include the document, #{@doc.sourcedb}:#{@doc.sourceid}.")
              end
            end
          end
        end
      end      

      context 'when project not found by nanme' do
        before do
          delete :destroy, :project_id => @project_id, :id => ''
        end
        
        it 'should redirect_to pmdocs_path' do
          response.should redirect_to(pmdocs_path)
        end

        it 'should not set flash[:notice]' do
          flash[:notice].should eql("The annotation set, #{@project_id}, does not exist.")
        end
      end
    end
  end
  
  describe 'search' do
    context 'without pagination' do
      before do
        @pmc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => 234)
        @sourceid_123 = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 123)
        @sourceid_1234 = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1234)
        @sourceid_1123 = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1123)
        @sourceid_234 = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 234)
      end
      
      context 'when params[:sourceid] and params[:body] is nil' do
        before do
          get :search
        end  
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
                
        it 'should not include sourcedb is not PubMed' do
          assigns[:docs].should_not include(@pmc)
        end
        
        it 'should include soucedb is PubMed' do
          assigns[:docs].should include(@sourceid_123)
        end
  
        it 'should include soucedb is PubMed' do
          assigns[:docs].should include(@sourceid_1234)
        end
  
        it 'should include soucedb is PubMed' do
          assigns[:docs].should include(@sourceid_1123)
        end
  
        it 'should include soucedb is PubMed' do
          assigns[:docs].should include(@sourceid_234)
        end
      end
            
      context 'when params[:sourceid] present' do
        before do
          get :search, :sourceid => '123'
        end
        
        it '@pm_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pm_sourceid_value].should be_eql('123')
        end
        
        it '@pm_body_value shoould be nil' do
          assigns[:pm_body_value].should be_nil
        end
                
        it 'should not include sourcedb is not PubMed' do
          assigns[:docs].should_not include(@pmc)
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
          @sourceid_123_test = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 123, :body => 'test')
          @sourceid_1234_test = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1234, :body => 'testmatch')
          @sourceid_234_test = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 234, :body => 'matchtest')
          @sourceid_123_est = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 123, :body => 'est')
          get :search, :body => 'test'
        end
        
        it '@pm_sourceid_value shoould be nil' do
          assigns[:pm_sourceid_value].should be_nil
        end
        
        it '@pm_body_value shoould be == params[:body]' do
          assigns[:pm_body_value].should be_eql('test')
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
          @sourceid_1_body_test = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1, :body => 'test')
          @sourceid_1_body_test_and = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1, :body => 'testand')
          @sourceid_1_body_nil = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1, :body => nil)
          @sourceid_2_body_test = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0, :sourceid => 2, :body => 'test')
          get :search, :sourceid => 1, :body => 'test'
        end
         
        it '@pm_sourceid_value shoould be == params[:sourceid]' do
          assigns[:pm_sourceid_value].should be_eql('1')
        end
        
        it '@pm_body_value shoould be == params[:body]' do
          assigns[:pm_body_value].should be_eql('test')
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
        @first_page = FactoryGirl.create(:doc, :id => 1, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1)
        i = 2
        WillPaginate.per_page.times do
          FactoryGirl.create(:doc, :id => i, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1)
          i += 1
        end
        @next_page = FactoryGirl.create(:doc, :id => i, :sourcedb => 'PubMed', :serial => 0, :sourceid => 1)
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
          response.should redirect_to(sql_pmdocs_path)
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