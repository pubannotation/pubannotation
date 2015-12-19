# encoding: utf-8
require 'spec_helper'

describe DocsController do
  describe 'index' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => '123')
      @project.docs << @project_doc  
      @source_db_id = Doc.all
      # Doc.stub(:source_db_id).and_return(@source_db_id)
      @sort_by_params = double(:sort_by_params)
      Doc.stub(:sort_by_params).and_return(@sort_by_params)
      @paginate = 'paginate'
      @sort_by_params.stub(:paginate).and_return(@paginate)
      @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => '123')  
    end
    
    context 'when params[:project_id] present' do
      context 'when format html' do
        before do
          get :index, :project_id => @project.name
        end
        
        it 'should assign project' do
          assigns[:project].should eql(@project)
        end

        it 'should assign project.docs as @docs' do
          assigns[:docs].should =~ @project.docs
        end

        it 'should assigns project.docs to hash as @docs_hash' do
          assigns[:docs_hash].should =~ @project.docs.collect{|doc| doc.to_list_hash('doc').stringify_keys}
        end

        it 'should assing sort_by_params.paginate as @source_docs' do
          assigns[:source_docs].should eql(@paginate)
        end
        
        it 'should assign search_project_docs_path as @search_path' do
          assigns[:search_path].should eql search_project_docs_path(@project.name)
        end

        it 'should call sort_order with Doc' do
          controller.should_receive(:sort_order).with(Doc)
          get :index, :project_id => @project.name
        end
      end

      context 'when format json' do
        before do
          @docs_hash = @project.docs.collect{|doc| doc.to_list_hash('doc').stringify_keys}
          get :index, format: 'json', :project_id => @project.name
        end

        it 'should assigns project.docs to hash as @docs_hash' do
          assigns[:docs_hash].should =~ @docs_hash
        end

        it 'should render @docs_hash to_json' do
          response.body.should eql(@docs_hash.to_json)
        end
      end

      context 'when format tsv' do
        before do
          @tsv = 'tsv'
          Doc.stub(:to_tsv).and_return(@tsv)
          get :index, format: 'tsv', :project_id => @project.name
        end

        it 'should render @docs_hash to_tsv' do
          response.body.should eql(@tsv)
        end
      end
    end    
    
    context 'when params[:project_id] blank' do
      before do
        get :index
      end

      it 'should assign Doc as @docs' do
        assigns[:docs].should eql(Doc)
      end

      it 'shoud assign too many message as @doc_hash' do
        assigns[:docs_hash].should eql({'message' => I18n.t('controllers.docs.index.too_many')})
      end
      
      it 'should assign search_docs_path as @search_path' do
        assigns[:search_path].should eql search_docs_path
      end
    end   
  end
  
  describe 'records' do
    before do
      @doc = FactoryGirl.create(:doc, :sourceid => 'sourceid', :serial => 1, :section => 'section')
    end
    
    context 'when params[:project_id] exists' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_id = 'project id'
        @get_project_notice = 'get project notice'
      end
      
      context 'when get_project returns project' do
        before do
          controller.stub(:get_project).and_return([@project, @get_project_notice])
          get :records, :project_id => @project_id
        end
        
        it 'should render template' do
          response.should render_template('records')
        end
      end

      context 'when get_project does not returns project' do
        before do
          controller.stub(:get_project).and_return([nil, @get_project_notice])
        end
        
        context 'when format html' do
          before do
            get :records, :project_id => @project_id
          end
          
          it 'should render template' do
            response.should render_template('records')
          end
          
          it 'set get_project notice as flash[:notice]' do
            flash[:notice].should eql(@get_project_notice)
          end
        end
        
        context 'when format json' do
          before do
            get :records, :format => 'json', :project_id => @project_id
          end
          
          it 'should return status 422' do
            response.status.should eql(422)
          end
        end
        
        context 'when format text' do
          before do
            get :records, :format => 'txt', :project_id => @project_id
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
          get :records
        end
        
        it 'should render template' do
          response.should render_template('records')
        end
      end

      context 'when format json' do
        before do
          get :records, :format => 'json'
        end
        
        it 'should render @docs as json' do
          response.body.should eql(assigns[:docs].to_json)
        end
      end

      context 'when format text' do
        before do
          get :records, :format => 'txt'
        end
        
        it 'should return zpi' do
          response.content_type.should eql("application/zip")
        end
      end
    end
  end
  
  describe 'sourcedb_index' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      # create docs belongs to project
      @project_doc_1 = FactoryGirl.create(:doc, :sourcedb => "sourcedb1")
      @project.docs << @project_doc_1
      @project_doc_2 = FactoryGirl.create(:doc, :sourcedb => "sourcedb2")
      @project.docs << @project_doc_2
      # create docs not belongs to project
      2.times do
        FactoryGirl.create(:doc, :sourcedb => 'sdb')
      end
    end

    context 'when params[:project_id] present' do
      before do
        get :sourcedb_index, :project_id => @project.name
      end  
      
      it 'should include project.docs sourcedb' do
        assigns[:sourcedbs].collect{|doc| doc.sourcedb}.uniq.should =~ @project.docs.collect{|doc| doc.sourcedb}
      end    
    end

    context 'when params[:project_id] blank' do
      before do
        get :sourcedb_index
      end  
      
      it 'should not contatin blank sourcedb' do
        assigns[:sourcedbs].select{|doc| doc.sourcedb == nil || doc.sourcedb == ''}.should be_blank
      end    
    end
  end
  
  describe 'sourceid_index' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :name => 'project name')
      @sourcedb = 'source db'
      @project_doc = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => '123')
      @project_doc_2 = FactoryGirl.create(:doc, :sourcedb => 'sdb', :sourceid => '123')
      @paginate = 'paginate'
    end
    
    context 'when params[:project_id] present' do
      before do
        Project.any_instance.stub_chain(:docs, :where, :where, :sort_by_params, :paginate).and_return(@paginate)
      end

      it 'should assing @project.docs.where.wheresort_by_params.paginate as @source_docs' do
        get :sourceid_index, :project_id => @project.name, :sourcedb => @sourcedb
        assigns[:source_docs].should eql(@paginate)
      end

      it 'should call sort_order with Doc' do
        controller.should_receive(:sort_order).with(Doc)
        get :sourceid_index, :project_id => @project.name, :sourcedb => @sourcedb
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        Doc.stub_chain(:where, :where, :sort_by_params, :paginate).and_return(@paginate)
        get :sourceid_index, :sourcedb => @sourcedb
      end
      
      it 'should assing @project.docs.where.wheresort_by_params.paginate as @source_docs' do
        assigns[:source_docs].should eql(@paginate)
      end

      it 'should assign search_docs_path as @search_path' do
        assigns[:search_path].should eql search_docs_path
      end
    end
  end

  describe 'search' do
    before do
      user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: user)
      @current_user = nil
      current_user_stub(@current_user)
      @sourcedb = 'sdb'
      @sourceid = '123456'
      @body = 'body'
    end

    context 'when params[:project_id] present' do
      before do
        Project.stub_chain(:accessible, :find_by_name).and_return(@project)
      end

      it 'should call Project.accessible scope' do
        expect(Project).to receive(:accessible).with(@current_user)
        post :search, project_id: @project.name
      end

      it 'should find project by project_id(project.name) from Project.accessible' do
        expect(Project.accessible).to receive(:find_by_name).with(@project.name)
        post :search, project_id: @project.name
      end

      it 'should set Project.accessible(current_user).find_by_name(params[:project_id]) as @project' do
        post :search, project_id: @project.name
        expect(assigns[:project]).to eql(@project)
      end

      it 'should search_docs with project_id' do
        expect(Doc).to receive(:search_docs).with({sourcedb: @sourcedb, sourceid: @sourceid, body: @body, project_id: @project.id})
        post :search, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid, body: @body
      end
    end

    context 'when params[:project_id] blank' do
      it 'should search_docs without project_id' do
        expect(Doc).to receive(:search_docs).with({sourcedb: @sourcedb, sourceid: @sourceid, body: @body, project_id: nil})
        post :search, sourcedb: @sourcedb, sourceid: @sourceid, body: @body
      end
    end

    describe 'search_results[:total]' do
      context 'when results greater hant Doc::SEARCH_SIZE' do
        before do
          @total_size = Doc::SEARCH_SIZE + 1
          docs = double(:docs)
          docs.stub(:paginate).and_return(docs)
          docs.stub(:count).and_return(1)
          docs.stub(:map).and_return(1)
          Doc.stub(:search_docs).and_return({docs: docs, total: @total_size})
        end

        it 'should set flash[:notice]' do
          post :search, sourcedb: @sourcedb, sourceid: @sourceid, body: @body
          flash[:notice].should eql(I18n.t('controllers.docs.search.greater_than_search_size', total: @total_size, search_size: Doc::SEARCH_SIZE))
        end
      end
    end

    describe 'search_docs count' do
      context 'when results greater hant Doc::SEARCH_SIZE' do
        before do
          @total_size = Doc::SEARCH_SIZE + 1
          @docs = double(:docs)
          @docs.stub(:paginate).and_return(@docs)
          @docs.stub(:map).and_return(1)
          Doc.stub(:search_docs).and_return({docs: @docs, total: @total_size})
        end

        context 'when search_docs.count < 5000' do
          before do
            @search_docs_count = 1
            @docs.stub(:count).and_return(@search_docs_count)
          end

          it 'should map search_docs to_list_hash' do
            expect(@docs).to receive(:map)
            post :search, sourcedb: @sourcedb, sourceid: @sourceid, body: @body
          end

          it 'should assign search_docs.count as @search_docs_number' do
            post :search, sourcedb: @sourcedb, sourceid: @sourceid, body: @body
            expect(assigns[:docs_size]).to eql(@search_docs_count)
          end

          it 'should assign search_docs as @source_docs' do
            post :search
            expect(assigns[:source_docs]).to eql(@docs)
          end
        end

        context 'when search_docs.count > 5000' do
          before do
            @search_docs_count = 6000
            @docs.stub(:count).and_return(@search_docs_count)
          end


          it 'should render blank array as json' do
            post :search, format: 'json'
            expect(response.body).to eql([].to_json)
          end
        end
      end
    end

    describe 'when error raised' do
      before do
        @error = 'error'
        Doc.stub(:search_docs).and_raise(@error)
      end

      context 'when format html' do
        context 'when @project.present' do
          before do
            Project.stub_chain(:accessible, :find_by_name).and_return(@project)
            @project.stub(:docs).and_raise('error')
            post :search, project_id: @project.name
          end

          it 'should set error.message as flash[:notice]' do
            expect(flash[:notice]).to eql(@error)
          end

          it 'should redirect_to @project' do
            expect(response).to redirect_to(project_path(@project.name))
          end
        end

        context 'when @project.blank' do
          it 'should redirect_to docs_path' do
            post :search
            expect(response).to redirect_to(docs_path)
          end
        end
      end

      context 'when format json' do
        before do
          post :search, format: 'json'
        end

        it 'should render error as json' do
          expect(response.body).to eql({notice: @error}.to_json)
        end

        it 'should return status 422' do
          expect(response.status).to eql(422)
        end
      end

      context 'when format tsv' do
        before do
          post :search, format: 'tsv'
        end

        it 'should render error as json' do
          expect(response.body).to eql(@error)
        end

        it 'should return status 422' do
          expect(response.status).to eql(422)
        end
      end
    end
  end
  
  describe 'show' do
    before do
      current_user_stub(nil)
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sd', :sourceid => '123456')  
    end
    
    context 'when params id present' do
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
        
        it 'should render @doc_hash as json' do
          response.body.should eql(@doc.to_hash.to_json)
        end
      end
    end
    
    context 'when params sourcedb sourceid present' do
      context 'when docs.length == 1' do
        context 'when format html' do
          before do
            get :show, :sourcedb  => @doc.sourcedb, :sourceid => @doc.sourceid 
          end

          it 'shoud assign Doc match sourcedb and sourceid first ad @doc' do
            assigns[:doc].should eql(@doc)
          end
          
          it 'should render template' do
            response.should render_template('show')
          end
        end
        
        context 'when format json' do
          before do
            get :show, :format => 'json', :sourcedb  => @doc.sourcedb, :sourceid => @doc.sourceid 
          end
          
          it 'should render @doc_hash as json' do
            response.body.should eql(@doc.to_hash.to_json)
          end
        end
      end
    end
    
    describe 'when @doc present' do
      before do
        @noice = 'notice'
        @current_user = FactoryGirl.create(:user)
        current_user_stub(@current_user)
        @project = FactoryGirl.create(:project, user: @current_user)
        # @doc.projects << @project
        @sort_by_params = 'sort_by_params'
        Doc.any_instance.stub_chain(:projects, :accessible, :sort_by_params).and_return(@sort_by_params)
      end
      
      it 'should assign @projects' do
        get :show, :id => @doc.id
        assigns[:projects].should eql @sort_by_params 
      end

      it 'should call sort_order with Project' do
        controller.should_receive(:sort_order).with(Project)
        get :show, :id => @doc.id
      end
    end
    
    describe 'when @doc blank docs present' do
      before do
        @noice = 'notice'
        FactoryGirl.create(:doc, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid.to_s)  
      end
      
      context 'when @project present' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          controller.stub(:get_project).and_return([@project, @notice])
          get :show, :sourcedb  => @doc.sourcedb, :sourceid => @doc.sourceid 
        end
        
        it 'should render template' do
          response.should redirect_to(index_project_sourcedb_sourceid_divs_docs_path(@project.name, @doc.sourcedb, @doc.sourceid))
        end
      end
      
      context 'when @project blank' do
        before do
          controller.stub(:get_project).and_return([nil, @notice])
          get :show, :sourcedb  => @doc.sourcedb, :sourceid => @doc.sourceid 
        end
        
        it 'should render template' do
          response.should redirect_to(doc_sourcedb_sourceid_divs_index_path)
        end
      end
    end
  end

  describe 'spans_index' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      controller.stub(:get_project).and_return([@project, nil])
      @doc = FactoryGirl.create(:doc, :sourceid => '12345', :sourcedb => 'PubMed', :serial => 0)
      controller.stub(:get_doc).and_return([@doc, nil])
    end

    context 'when format json' do
      before do
        @annotations = {text: 'text', tagget: 'target'}
        controller.stub(:get_annotations_for_json).and_return(@annotations)
        @denotations = 'denotations'
        controller.stub(:get_annotations).and_return({:denotations => [@denotations]})
        get :spans_index, :project_id => @project.name, :id => @doc.sourceid, format: 'json'
        @json = JSON.parse(response.body)
      end

      it 'should set get_annotations_for_json[:text] as json text' do
        expect(@json['text']).to eql(@annotations[:text])
      end

      it 'should set get_annotations_for_json[:target] as json target' do
        expect(@json['target']).to eql(@annotations[:target])
      end

      it 'should set get_annotations_for_json[:denotations] as json denotations' do
        expect(@json['denotations']).to eql([@denotations])
      end
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
      context 'when params id present' do
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
      
      context 'when params id blank' do
        before do
          @denotation = FactoryGirl.create(:denotation)
          @doc.denotations << @denotation
        end
        
        context 'when docs.lengs == 1' do
          before do
            get :spans_index, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid
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

        context 'when docs.lengs > 1' do
          before do
            @doc_2 = FactoryGirl.create(:doc, :sourceid => @doc.sourceid, :sourcedb => @doc.sourcedb, :serial => @doc.serial.to_i + 1 )
            get :spans_index, :sourcedb => @doc.sourcedb, :sourceid => @doc.sourceid, :divid => @doc.serial
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
    end
  end
  
  describe 'spans' do
    before do
      @body = 'doc body'
      @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
      @project = 'project'
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @projects = [@project_1]
      controller.stub(:get_project).and_return([@project, nil])
      @project_denotations_span = {begin: 0, end: 5}
      @project_denotations = [denotations: [{id: 'Ts', span: @project_denotations_span}]]
      controller.stub(:get_project_denotations).and_return(@project_denotations)
      @projects_sort_by_params = [@project_2]
      Project.stub_chain(:id_in, :sort_by_params).and_return(@projects_sort_by_params)
      @sort_order = 'sort_order'
      controller.stub(:sort_order).and_return(@sort_order)
      @text = 'doc text'
      @doc.stub(:text).and_return(@text)
      controller.stub(:get_doc).and_return([@doc, nil])
      @spans = 'SPANS'
      @prev_text = 'PREV'
      @next_text = 'NEXT'
      @doc.stub(:spans).and_return([@spans, @prev_text, @next_text])
    end
    
    context 'when params[:project_id] presents' do
      context 'when the format is html' do
        before do
          get :spans, :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
        end
        
        it 'should assign @project' do
          assigns[:project].should eql(@project)
        end
        
        it 'should not assign @projects' do
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

        it 'shoud assigns @text' do
          expect(assigns[:text]).to eql(@text)
        end

        it 'shoud assigns @project_denotations' do
          expect(assigns[:project_denotations]).to be_present
        end
      end

      context 'when the format is text' do
        before do
          @text = 'doc text'
          @doc.stub(:text).and_return(@text)
          get :spans, :format => 'txt', :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
        end

        it 'should render text' do
          expect(response.body).to eql(@text)
        end
      end

      context 'when the format is json' do
        before do
          @params_begin = 1
          @params_end = 5
          @get_focus = 'get_focus'
          controller.stub(:get_focus).and_return(@get_focus)
        end

        context 'when the context_size is not specified' do
          it 'should render json without focus' do
            get :spans, :format => 'json', :project_id => 1, :id => @doc.sourceid, :begin => @params_begin, :end => @params_end 
            expect(response.body).to eql({text: @text}.to_json)
          end
        end

        context 'when the context_size is specified' do
          it 'should render json with focus' do
            get :spans, :format => 'json', :project_id => 1, :id => @doc.sourceid, :begin => @params_begin, :end => @params_end, :context_size => 5 
            expect(response.body).to eql({text: @text, focus: @get_focus}.to_json)
          end
        end
      end

      context 'when format csv' do
        before do
          @csv = 'csv text'
          @doc.stub(:to_csv).and_return(@csv)
          get :spans, :format => 'csv', :project_id => 1, :id => @doc.sourceid, :begin => 1, :end => 5
        end

        it 'should render to_csv' do
          expect(response.body).to eql(@csv)
        end
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        @project_denotation = 'project denotations'
        @project_denotations = {:denotations => @project_denotation}
        controller.stub(:get_project_denotations).and_return([{project: @project_1, denotations: @project_denotations[:denotations]}])
      end

      context 'when doc.spans_projects(params). present' do
        before do
          @doc.stub(:spans_projects).and_return(@projects)
        end
        
        it 'should not assign @project' do
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
          assigns[:project].should be_nil
        end

        it 'shoud call sort_order with Project' do
          controller.should_receive(:sort_order).with(Project)
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
        end
        
        it 'should assign Project.id_in(@doc.spans_projects).sort_by_params @projects' do
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
          assigns[:projects].should eql(@projects_sort_by_params)
        end
        
        it 'should assign @project_denotations' do
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
          assigns[:project_denotations].should eql([{'project' => @project_1, 'denotations' => @project_denotation}])
        end

        it 'should assign @annotations_projects_check' do
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
          assigns[:annotations_projects_check].should be_present
        end

        it 'should assign @annotations_path without parameters' do
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
          assigns[:annotations_path].should eql("#{spans_doc_path(@doc.id, 1, 5)}/annotations")
        end
      end

      context 'when doc.spans_projects(params). present' do
        before do
          @doc.stub(:spans_projects).and_return(nil)
          get :spans, :id => @doc.id, :begin => 1, :end => 5, sort_direction: 'ASC'
        end
        
        it 'should not assign @projects' do
          assigns[:projects].should be_blank
        end
      end
    end
  end
  
  describe 'new' do
    before do
      controller.class.skip_before_filter :authenticate_user!
    end

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
      controller.class.skip_before_filter :authenticate_user!
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
    before do
      controller.class.skip_before_filter :authenticate_user!
    end

    context 'when save successfully' do
      context 'when format html' do
        context 'when project blank' do
          before do
            post :create, doc: {body: 'body', sourcedb: 'sourcedb', sourceid: 'sourceid', serial: 0}
          end
          
          it 'should redirect to doc_path' do
            response.should redirect_to(doc_path(assigns[:doc]))
          end
        end
        
        context 'when project present' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            controller.stub(:get_project).and_return(@project)
            post :create, doc: {body: 'body', sourcedb: 'sourcedb', sourceid: 'sourceid', serial: 0}, :project_id => @project.id
          end
          
          it 'should redirect to doc_path' do
            response.should redirect_to(project_doc_path(@project.name, assigns[:doc]))
          end
        end
      end

      context 'when format json' do
        before do
          post :create, doc: {body: 'body', sourcedb: 'sourcedb', sourceid: 'sourceid', serial: 0}, :format => 'json'
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
  
  describe 'add' do
    before do
      controller.class.skip_before_filter :http_basic_authenticate
      controller.class.skip_before_filter :authenticate_user!
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @sourcedb = 'PMC'
      controller.stub(:get_project).and_return([@project, nil])
      @num_created = 1
      @num_added = 2
      @num_failed = 3
      @project.stub(:add_docs_from_json).and_return([@num_created, @num_added, @num_failed])
    end

    context 'when the params, sourcedb and ids, present' do
      before do
        @id_1 = 'id_1'
        @id_2 = 'id_2'
        @ids = "#{@id_1}, #{@id_2}"
      end

      describe 'docs' do
        it 'should call project.add_docs_from_json with docs generated from params[:ids] and current_user' do
          @project.should_receive(:add_doc).with({sourcedb: @sourcedb, sourceid: @id_1}, @current_user)
          @project.should_receive(:add_doc).with({sourcedb: @sourcedb, sourceid: @id_2}, @current_user)
          get :add, project_id: @project.name, sourcedb: @sourcedb, ids: @ids
        end
      end

      describe 'format' do
        context 'when format html' do
          before do
            get :add, project_id: @project.name, sourcedb: @sourcedb, ids: @ids
          end

          it 'should set flash[:notice] from number of created, added and failed' do
            flash[:notice].should eql("created: #{@num_created}, added: #{@num_added}, failed: #{@num_failed}")
          end

          it 'should redirect_to project_docs_path' do
            response.should redirect_to(project_docs_path(@project.name))
          end
        end

        context 'when format json' do
          context 'when num_created > 0' do
            before do
              get :add, :project_id => @project.name, ids: @ids, sourcedb: @sourcedb, format: 'json'
            end

            it 'should render result as json' do
              response.body.should eql({created: @num_created, added: @num_added, failed: @num_failed}.to_json)
            end

            it 'should return status created' do
              response.status.should eql(201)
            end

            it 'should return project_docs_path as location' do
              response.location.should eql(project_docs_path(@project.name))
            end
          end

          context 'when num_created == 0' do
            before do
              @num_created = 0
            end

            context 'when num_added > 0' do
              before do
                @project.stub(:add_docs_from_json).and_return([@num_created, @num_added, @num_failed])
                get :add, :project_id => @project.name, ids: @ids, sourcedb: @sourcedb, format: 'json'
              end

              it 'should render result as json' do
                response.body.should eql({created: @num_created, added: @num_added, failed: @num_failed}.to_json)
              end

              it 'should return status created' do
                response.status.should eql(201)
              end

              it 'should return project_docs_path as location' do
                response.location.should eql(project_docs_path(@project.name))
              end
            end

            context 'when num_added == 0' do
              before do
                @num_added = 0
                @project.stub(:add_docs_from_json).and_return([@num_created, @num_added, @num_failed])
                get :add, :project_id => @project.name, ids: @ids, sourcedb: @sourcedb, format: 'json'
              end

              it 'should render result as json' do
                response.body.should eql({created: @num_created, added: @num_added, failed: @num_failed}.to_json)
              end

              it 'should return status unprocessable_entity' do
                response.status.should eql(422)
              end

              it 'should  not return location' do
                response.location.should be_nil
              end
            end
          end
        end
      end
    end

    context 'when params docs present' do
      before do
        @docs = [{id: '1'}]
      end

      it 'should call project.add_docs_from_json with docs symbolize_keys docs and current_user' do
        @project.should_receive(:add_docs_from_json).with(@docs.collect{|d| d.symbolize_keys}, @current_user)
        get :add, :project_id => @project.name, docs: @docs
      end
    end
  end
  
  describe 'update' do
    before do
      controller.class.skip_before_filter :authenticate_user!
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
      controller.class.skip_before_filter :authenticate_user!
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when params[:project_id] present' do
      context 'format html' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @project.docs << @doc
          @project.reload
        end
        
        describe 'before post' do
          it 'doc should included in project.docs' do
            @project.docs.should include @doc
          end
        end
        
        describe 'adter post' do
          before do
            delete :destroy, :id => @doc.id, :project_id => @project.name
            @project.reload
          end  
          
          it 'doc should not included in project.docs' do
            @project.docs.should_not include @doc
          end
        
          it 'should not destory doc' do
            Doc.find_by_id(@doc.id).should be_present
          end
          
          it 'should redirect to docs_url' do
            response.should redirect_to(records_project_docs_path(@project.name))
          end
        end
        
      end
    end
    
    context 'when params[:project_id] blank' do
      context 'format html' do
        before do
          delete :destroy, :id => @doc.id
        end
        
        it 'should destory doc' do
          Doc.find_by_id(@doc.id).should be_nil
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
  
  describe 'delete_project_docs' do
    before do
      controller.class.skip_before_filter :authenticate_user!
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @sourcedb = 'PMC'
      @sourceid = '123456'
      @project_doc_1  = FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid, serial: 0)
      @project.docs << @project_doc_1
      @project_doc_2  = FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid, serial: 1)
      @project.docs << @project_doc_2
      @project_doc_3  = FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid + '1')
      @project.docs << @project_doc_3
      @project_doc_4  = FactoryGirl.create(:doc, sourcedb: 'PubMed', sourceid: @sourceid)
      @project.docs << @project_doc_4
      @refrerer = root_path
      request.env["HTTP_REFERER"] = @refrerer
      @project.reload
    end
    
    describe 'before delete' do
      it 'project has 4docs' do
        @project.docs.size.should eql 4
      end
    end
    
    describe 'before delete' do
      before do
        delete :delete_project_docs, project_id: @project.name, sourcedb: @sourcedb, sourceid: @sourceid 
        @project.reload
      end
      
      it 'should delete 2docs from poject docs' do
        @project.docs.size.should eql 2 
      end
      
      it 'should not destroy doc' do
        Doc.find(@project_doc_1).should be_present
        Doc.find(@project_doc_2).should be_present
      end
      
      it 'should redirect_to back' do
        response.should redirect_to @refrerer
      end
    end
  end 

  describe 'autocomplete_sourcedb' do
    before do
      @sourcedbs = %w(sdb1 sdb2 SDB3)
      @sourcedbs.each do |sourcedb|
        2.times do |time|
          FactoryGirl.create(:doc, sourcedb: sourcedb, sourceid: time.to_s )
        end
      end
    end

    context 'when matched' do
      it 'should return unique sourcedbs as json' do
        get :autocomplete_sourcedb, term: 'sdb'
        expect(response.body).to eql @sourcedbs.to_json
      end
    end

    context 'when not matched' do
      it 'should blank array as json' do
        get :autocomplete_sourcedb, term: 'AAA'
        expect(response.body).to eql [].to_json
      end
    end
  end

  describe 'set_access_control_headers' do
    before do
      @controller = DocsController.new
      @headers = {'Access-Control-Allow-Origin' => nil}
      @controller.stub(:headers).and_return(@headers)
    end

    context 'when allowed_origins includes' do
      before do
        @controller.stub(:request).and_return(double(env: {'HTTP_ORIGIN' => 'http://localhost'}))
      end

      it 'should return headers[Access-Control-Max-Age]' do
        @result = @controller.instance_eval{
          set_access_control_headers
        }
        @result.should eql "1728000"
      end
    end

    context 'when allowed_origins not includes' do
      before do
        @controller.stub(:request).and_return(double(env: {'HTTP_ORIGIN' => 'remote'}))
      end

      it 'should return nil' do
        @result = @controller.instance_eval{
          set_access_control_headers
        }
        @result.should be_nil 
      end
    end
  end
end
