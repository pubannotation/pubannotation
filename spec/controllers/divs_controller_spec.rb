# encoding: utf-8
require 'spec_helper'

describe DivsController do
  describe 'index' do
    before do
      @pmcdoc_id = 'sourceid'
      @doc_pmc_sourceid = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @pmcdoc_id)
      @doc_not_pmc = FactoryGirl.create(:doc, :sourcedb => 'AAA', :sourceid => @pmcdoc_id)
      @project_id = 'project_id'
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => @project_id)
      @tsv = 'tsv'
      Doc.stub(:to_tsv).and_return(@tsv)
    end
    
    context 'when params[:project_id] present' do
      context 'when format html' do
        before do
          get :index, :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
        end
        
        it '@docs should include only sourcedb and sourceid match' do
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
          get :index, :format => 'json', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
        end
        
        it 'should render json' do
          response.body.should eql(assigns[:docs].collect{|d| d.to_list_hash('div')}.to_json)
        end
      end
  
      context 'when format tsv' do
        before do
          @docs = [FactoryGirl.create(:doc)]
          Doc.stub(:find_all_by_sourcedb_and_sourceid).and_return(@docs)
        end
        
        it 'should call to_tsv with docsa and div doc_type' do
          Doc.should_receive(:to_tsv).with(@docs, 'div')
          get :index, :format => 'tsv', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
        end
        
        it 'should render tsv' do
          get :index, :format => 'tsv', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
          response.body.should eql(@tsv)
        end
      end
  
      context 'when format txt' do
        context 'when @project present' do
          before do
            get :index, :format => 'txt', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_id
          end

          it 'should redirect' do
            response.should redirect_to(show_project_sourcedb_sourceid_docs_path(@project.name, @doc_pmc_sourceid.sourcedb, @doc_pmc_sourceid.sourceid, format: :txt))
          end
        end

        context 'when @project is nil' do
          before do
            @project_name = 'invalid'
            get :index, :format => 'txt', :sourcedb => @doc_pmc_sourceid.sourcedb, :sourceid => @doc_pmc_sourceid.sourceid, :project_id => @project_name
          end

          it 'should redirect' do
            response.should redirect_to(doc_sourcedb_sourceid_show_path(@project_name, @doc_pmc_sourceid.sourcedb, @doc_pmc_sourceid.sourceid, format: :txt))
          end
        end
      end
    end
  end
  
  describe 'show' do
    before do
      @id = 'id'
      @pmcdoc_id = 'pmc doc id'
      @asciitext = 'aschii text'
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '123', :serial => 0)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @get_doc_notice = 'get doc notice'
    end

    context 'when params[:project_id] exists' do
      before do
        @project_id = 'project id'
        @get_project_notice = 'get project notice'
      end
      
      context 'when get_project returns project' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
          controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
          @annotations = 'annotations'
          controller.stub(:get_annotations).and_return(@annotations)
        end

        describe 'except format' do
          before do
            get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it 'should set get_doc notice as flash[:notice]' do
            flash[:notice].should eql(@get_doc_notice)  
          end

          it 'should set get_project project as @project' do
            assigns[:project].should eql(@project)
          end

          it 'should set get_annotations annotations as @annotations' do
            assigns[:annotations].should eql(@annotations)
          end
        end

        describe 'format' do
          context 'format html' do
            before do
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
            end
          
            it 'should render template' do
              response.should render_template('docs/show')
            end
          end

          context 'when format json' do
            before do
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id, :format => 'json'
            end

            it 'set @doc.to_hash as @doc_hash' do
              assigns[:doc_hash].should include @doc.to_hash
            end
            
            it 'should render @doc.to_hash as json' do
              response.body.should eql(@doc.to_hash.to_json)
            end
          end

          context 'when format text' do
            before do
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id, :format => 'txt'
            end
            
            it 'should render doc.body' do
              response.body.should eql(@doc.body)
            end
          end

          context 'when encoding ascii' do
            before do
              @asciitext = 'ascii'
              @doc.stub(:get_ascii_text).and_return(@asciitext)
              get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id, :encoding => 'ascii'
            end
            
            it '@text should getr_ascii_text' do
              assigns[:doc][:body].should eql(@asciitext)
            end
          end
        end
      end
      
      context 'when get_project does not returns project' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
        end
        
        context 'when format html' do
          before do
            @refrerer = root_path
            request.env["HTTP_REFERER"] = @refrerer
            get :show, :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it '@doc should be nil' do
            assigns[:doc].should be_nil
          end  
          
          it 'should redirect to back' do
            response.should redirect_to(@refrerer)
          end
          
          it 'should set flash[:notice]' do
            flash[:notice].should eql(@get_project_notice)
          end
        end  
        
        context 'when format json' do
          before do
            get :show, :format => 'json', :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
        
        context 'when format txt' do
          before do
            get :show, :format => 'txt', :project_id => @project_id, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :div_id => @id
          end

          it 'should returns status 422' do
            response.status.should eql(422)
          end  
        end  
      end
    end
    
    context 'when params[:project_id] does not exists' do
      before do
        controller.stub(:get_doc).and_return([@doc, @get_doc_notice])
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
        @project_1 = FactoryGirl.create(:project, user: @current_user, name: 'project1', author: 'AAA BBB')
        @doc.projects << @project_1
        @project_2 = FactoryGirl.create(:project, user: @current_user, name: 'project2', author: 'BBB CCC')
        @doc.projects << @project_2
      end

      context 'normal case' do
        before do
          @sort_order = 'sort_order'
          controller.stub(:sort_order).and_return(@sort_order)
          @sort_projects = 'sort projects'
          @doc.stub_chain(:projects, :accessible, :sort_by_params).and_return(@sort_projects) 
          @sourcedb = @doc.sourcedb
          @sourceid = @doc.sourceid
          @div_id = @doc.serial
        end

        it 'should call get_doc with params sourcedb, sourceid and div_id' do
          controller.should_receive(:get_doc).with(@doc.sourcedb, @doc.sourceid, @doc.serial.to_s)
          get :show, sourcedb: @sourcedb, sourceid: @sourceid, div_id: @div_id
        end

        it 'should call sort_order with Project' do
          controller.should_receive(:sort_order).with(Project)
          get :show, sourcedb: @sourcedb, sourceid: @sourceid, div_id: @div_id
        end

        it 'should call sort_order with Project' do
          controller.should_receive(:sort_order).with(Project)
          get :show, sourcedb: @sourcedb, sourceid: @sourceid, div_id: @div_id
        end

        it 'should set @doc.projects.accessible.sort_by_params as @project' do
          get :show, sourcedb: @sourcedb, sourceid: @sourceid, div_id: @div_id
          assigns[:projects].should eql(@sort_projects)
        end
      end
    end
  end
end
