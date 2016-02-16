  
  describe 'order_maintainer' do
    before do
      @user_1 = FactoryGirl.create(:user, username: 'AAA')
      @user_2 = FactoryGirl.create(:user, username: 'BBB')
      @user_3 = FactoryGirl.create(:user, username: 'CCC')
      @project_1 = FactoryGirl.create(:project, :user => @user_1)
      @project_2 = FactoryGirl.create(:project, :user => @user_2)
      @project_3 = FactoryGirl.create(:project, :user => @user_3)
      @projects = Project.order_maintainer
    end
    
    it 'should order by author' do
      @projects[0].should eql(@project_1)
    end
    
    it 'should order by author' do
      @projects[1].should eql(@project_2)
    end
    
    it 'should order by author' do
      @projects[2].should eql(@project_3)
    end
  end
  
  describe 'order_maintainer' do
    before do
      @project_1_user = FactoryGirl.create(:user, :username => 'AAA AAAA')
      @project_1 = FactoryGirl.create(:project, :user => @project_1_user)
      @project_2_user = FactoryGirl.create(:user, :username => 'AAA AAAB')
      @project_2 = FactoryGirl.create(:project, :user => @project_2_user)
      @project_3_user = FactoryGirl.create(:user, :username => 'AAA AAAc')
      @project_3 = FactoryGirl.create(:project, :user => @project_3_user)
      @projects = Project.order_maintainer
    end
    
    it 'should order by author' do
      @projects[0].should eql(@project_1)
    end
    
    it 'should order by author' do
      @projects[1].should eql(@project_2)
    end
    
    it 'should order by author' do
      @projects[2].should eql(@project_3)
    end
  end
  
  describe 'scope :order_association' do
    before do
      @current_user = FactoryGirl.create(:user)
      # create other users project
      2.times do
        FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      end
      @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @user_project = FactoryGirl.create(:project, :user => @current_user)
      FactoryGirl.create(:associate_maintainer, :user => @current_user, :project => @associate_project)        
    end
    
    context 'when current_user.present' do
      before do
        @projects = Project.order_association(@current_user)
      end
      
      it 'should set users project as first' do
        @projects.first.should eql(@user_project)
      end
      
      it 'should set users associate project as first' do
        @projects.second.should eql(@associate_project)
      end
    end

    context 'when current_user.blank' do
      before do
        @all_projects = Project.order('id DESC')        
        @projects = Project.order('id DESC').order_association(nil)
      end
      
      it 'should return @projects as same order projects' do
        @projects.each_with_index do |project, index|
          project.should eql(@all_projects[index])
        end
      end
    end
  end
  
  describe 'self.order_by' do
    before do
      @order_author = 'order_author'
      @order_maintainer = 'order_maintainer'
      @order_association = 'order_association'
      @order_else = 'order_else'
      # stub scopes
      Project.stub(:accessible).and_return(double({
          :order_author => @order_author,
          :order_maintainer => @order_maintainer,
          :order_association => @order_association,
          :order => @order_else
        }))
    end
    
    it 'order by author should return accessible and order_author scope result' do
      Project.order_by(Project, 'author', nil).should eql(@order_author)
    end
    
    it 'order by maintainer should return accessible and order_maintainer scope result' do
      Project.order_by(Project, 'maintainer', nil).should eql(@order_maintainer)
    end
    
    it 'order by else should return accessible and orde by name ASC' do
      Project.order_by(Project, nil, nil).should eql(@order_association)
    end
  end
   
  describe 'updatable_for?' do
    before do
      @project_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @project_user)
      @associate_maintainer_user_1 = FactoryGirl.create(:user)
      @project.associate_maintainers.create({:user_id => @associate_maintainer_user_1.id})
      @associate_maintainer_user_2 = FactoryGirl.create(:user)
      @project.associate_maintainers.create({:user_id => @associate_maintainer_user_2.id})
    end
    

    context 'when user.root is true' do
      before do
        @user = FactoryGirl.create(:user, root: true)
      end

      it 'should return true' do
        @project.updatable_for?(@user).should be_true
      end
    end

    context 'when current_user is project.user' do
      it 'should return true' do
        @project.updatable_for?(@project_user).should be_true
      end
    end
    
    context 'when current_user is project.associate_maintainer.user' do
      it 'should return true' do
        @project.updatable_for?(@associate_maintainer_user_1).should be_true
      end
    end
    
    context 'when current_user is project.associate_maintainer.user' do
      it 'should return true' do
        @project.updatable_for?(@associate_maintainer_user_2).should be_true
      end
    end
    
    context 'when current_user is not project.user nor project.associate_maintainer.user' do
      it 'should return false' do
        @project.updatable_for?(FactoryGirl.create(:user)).should be_false
      end
    end
  end
  
  describe 'notices_destroyable_for?' do
    before do
      @current_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: @current_user)
      @notice = FactoryGirl.create(:notice, project: @project)
    end

    context 'when current.prensent? == true' do
      context 'when current.root? = true' do
        before do
          @current_user.stub(:root?).and_return(true)
        end

        it 'should return true' do
          @project.notices_destroyable_for?(@current_user).should be_true 
        end
      end

      context 'when current.roo? = false' do
        before do
          @current_user.stub(:roo?).and_return(false)
        end

        context 'when current_user == project.user' do
          it 'should return true' do
            @project.notices_destroyable_for?(@current_user).should be_true 
          end
        end

        context 'when current_user != project.user' do
          it 'should return false' do
            @project.notices_destroyable_for?(FactoryGirl.create(:user)).should be_false 
          end
        end
      end
    end

    context 'when current.prensent? == false' do
      it 'should return false' do
        @project.notices_destroyable_for?(nil).should be_false 
      end
    end
  end
  
  describe 'association_for' do
    before do
      @project_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @project_user)
      @associate_maintainer_user = FactoryGirl.create(:user)
      @project.associate_maintainers.create({:user_id => @associate_maintainer_user.id})
    end
    
    context 'when current_user is project.user' do
      it 'should return M' do
        @project.association_for(@project_user).should eql('M')
      end
    end
    
    context 'when current_user is associate_maintainer_user' do
      it 'should return M' do
        @project.association_for(@associate_maintainer_user).should eql('A')
      end
    end
    
    context 'when current_user is no-relation' do
      it 'should return nil' do
        @project.association_for(FactoryGirl.create(:user)).should be_nil
      end
    end
  end
  describe 'increment_annotations_count' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end

    describe 'before add denotations, relations or modifications' do
      it 'annotations_count should equal 0' do
        expect( @project.annotations_count ).to eql 0
      end
    end

    context '' do
      before do
        denotation = FactoryGirl.create(:denotation)
        FactoryGirl.create(:relation, project: @project, :obj => denotation)
        @project.reload
      end

      it '' do
        expect( @project.annotations_count ).to eql 1
      end
    end
  end
  
  describe 'add associate projects' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_pmdocs_count = 1
      @project_pmdocs_count.times do
        doc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PubMed')
        @project.docs << doc
      end
      @project_pmcdocs_count = 2
      @project_pmcdocs_count.times do |time|
        doc = FactoryGirl.create(:doc, :body => 'doc 2', :sourcedb => 'PMC', :serial => 0, sourceid: time.to_s)
        @project.docs << doc
      end
      @project_denotations_count = 3
      @di = 1
      @project_denotations_count.times do
        FactoryGirl.create(:denotation, :hid => 'T1', :begin => @di, :project => @project)
        @di += 1
      end
      @project.reload
      
      @associate_pmdocs_count = 10
      @associate_pmcdocs_count = 20
      @associate_denotations_count = 30
      @associate_project = FactoryGirl.create(:project, 
        :user => FactoryGirl.create(:user), 
        :pmdocs_count => @associate_pmdocs_count, 
        :pmcdocs_count => @associate_pmcdocs_count, 
        :denotations_count => @associate_denotations_count)
      @dup_pmdocs_count = 2
      @i = 1
      @dup_pmdocs_count.times do
        pmdoc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PubMed', :sourceid => @i.to_s)
        @i += 1
        @associate_project.docs << pmdoc
      end

      @dup_pmcdocs_count = 3
      @dup_pmcdocs_count.times do
        pmcdoc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PMC', :serial => 0, :sourceid => @i.to_s)
        @i += 1
        @associate_project.docs << pmcdoc
      end

      @dup_denotations_count = 4
      @doc = FactoryGirl.create(:doc)
      @associate_project.docs << @doc
      @dup_denotations_count.times do
        FactoryGirl.create(:denotation, :hid => 'T1', :begin => @di, :project => @associate_project, :doc => @doc)
        @di += 1
      end
      @associate_project.reload
    end
    
    describe 'before add' do
      it 'associate project pmdocs_count should equal count nubmer and assocaite model count' do
        @associate_project.pmdocs_count.should eql @associate_pmdocs_count + @dup_pmdocs_count
      end

      it 'associate project pmcdocs_count should equal count nubmer and assocaite model count' do
        @associate_project.pmcdocs_count.should eql @associate_pmcdocs_count + @dup_pmcdocs_count
      end

      it 'associate project denotations_count should equal count nubmer and assocaite model count' do
        @associate_project.denotations_count.should eql @associate_denotations_count + @dup_denotations_count
      end
    end
    
    describe 'afte add' do
      before do
        @project.associate_projects << @associate_project
        @associate_project.reload
        @project.reload 
      end
      
      it 'should increment project.pmdocs_count as associate_project.pmdocs.count * 2' do
        @project.pmdocs_count.should eql(@project_pmdocs_count + (@dup_pmdocs_count * 2))
      end
      
      it 'should increment project.pmcdocs_count as associate_project.pmdocs.count * 2' do
        @project.pmcdocs_count.should eql(@project_pmcdocs_count + (@dup_pmcdocs_count * 2))
      end

      it 'should increment project.denotations_count as associate_project.denotations.count * 2' do
        @project.denotations_count.should eql(@project_denotations_count + (@dup_denotations_count * 2))
      end
    end
  end

  describe 'maintainer' do
    context 'when user present' do
      before do
        @user = FactoryGirl.create(:user)
        @project = FactoryGirl.create(:project, user: @user) 
      end

      it 'should return user.username' do
        @project.maintainer.should eql(@user.username)
      end
    end

    context 'when user blank' do
      before do
        @project = FactoryGirl.build(:project)
        @project.save(validate: false) 
      end

      it 'should be blank' do
        @project.maintainer.should be_blank
      end
    end
  end

  describe '#annotations_zip_filename' do
    before do
      @project_name = 'project_name'
      @project = FactoryGirl.create(:project, :name => @project_name, :user => FactoryGirl.create(:user))
    end

    it 'should return zip filename' do
      expect(@project.annotations_zip_filename).to eql("#{@project_name}-annotations.zip")
    end
  end
  
  describe '#annotations_zip_path' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @annotations_zip_filename = 'annotations.zip'
      @project.stub(:annotations_zip_filename).and_return(@annotations_zip_filename)
    end
    
    it 'should return project annotations zip path' do
      @project.annotations_zip_path.should eql("#{Project::DOWNLOADS_PATH}#{@annotations_zip_filename}")
    end
  end
  
  describe '#create_annotations_zip' do
    before do
      @name = 'rspec'
      Project.any_instance.stub(:get_doc_info).and_return('')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => @name)
    end

    describe 'create directory' do
      before do
        FileUtils.stub(:mkdir_p) do |path|
          @path = path
        end
      end

      context 'when downloads directory does not exist' do
        before do
          Dir.stub(:exist?).and_return(false)
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @project.create_annotations_zip
        end

        it 'should call mkdir_p with Project::DOWNLOADS_PATH' do
          @path.should eql(@project.downloads_system_path)
        end
      end

      context 'when downloads directory exists' do
        before do
          Dir.stub(:exist?).and_return(true)
          FactoryGirl.create(:project, :user => FactoryGirl.create(:user)).create_annotations_zip
        end

        it 'should not call mkdir_p' do
          @path.should be_nil
        end
      end
    end
    
    context 'when project.create_annotations_zip blank' do
      before do
        @result = @project.create_annotations_zip
      end
          
      it 'should not create ZIP file' do
        File.exist?("#{Project::DOWNLOADS_PATH}#{@name}.zip").should be_false
      end
    end
    
    context 'when project.anncollection present' do
      before do
        Project.any_instance.stub(:annotations_collection).and_return(
          [{
            :sourcedb => 'sourcedb',
            :sourceid => 'sourceid',
            :division_id => 1,
            :section => 'section',
         }])
         @result = @project.create_annotations_zip
      end
          
      it 'should create ZIP file' do
        File.exist?(@project.annotations_zip_system_path).should be_true
      end
      
      after do
        File.unlink(@project.annotations_zip_system_path)
      end
    end

    context 'when error occurred' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project.stub(:anncollection).and_raise('error')
      end

      it 'should create @project.notices' do
        expect{ @project.create_annotations_zip }.to change{ @project.notices.count }.from(0).to(1)
      end
    end
  end

  describe 'params_from_json' do
    before do
      @project_user = FactoryGirl.create(:user)
      json = {name: 'name', user_id: 1, created_at: DateTime.now, relations_count: 6, maintainer: @project_user.username}.to_json
      File.stub(:read).and_return(json)
      @params = Project.params_from_json('')
    end

    it 'should not include not attr_accessible column' do
      @params.select{|key, value| !Project.attr_accessible[:default].include?(key)}.size.should eql(0)
      @params.should eql({'name' => 'name'})
    end
  end

  describe 'create_from_zip' do
    pending do

      before do
        @zip_file = "#{Project::DOWNLOADS_PATH}project.zip"
        file = File.new(@zip_file, 'w')
        @doc_annotations_file = 'PMC-100-1-title.json'
        Zip::ZipOutputStream.open(file.path) do |z|
          z.put_next_entry('project.json')
          z.print ''
          z.put_next_entry('docs.json')
          z.print ''
          z.put_next_entry(@doc_annotations_file)
          z.print ''
        end
        file.close   
        @project_user = FactoryGirl.create(:user)
        @project_name = 'project name'
        Project.stub(:params_from_json).and_return({name: @project_name})
        @num_created = 1
        @num_added = 2
        @num_failed = 3
        Dir.stub(:exist?).and_return(false)
        Project.stub(:save_annotations) do |project, doc_annotations_files|
          @project = project
          @doc_annotations_files = doc_annotations_files
        end
        JSON.stub(:parse).and_return(nil)
      end

      context 'when project successfully saved' do
        before do
          Project.any_instance.stub(:add_docs_from_json).and_return([@num_created, @num_added, @num_failed])
          @messages, @errors = Project.create_from_zip(@zip_file, @project_name, @project_user)
        end

        it 'should create project' do
          Project.find_by_name(@project_name).should be_present
        end

        it 'messages should include project successfully created' do
          @messages.should include(I18n.t('controllers.shared.successfully_created', model: I18n.t('activerecord.models.project')))
        end

        it 'should include docs created' do
          @messages.should include(I18n.t('controllers.docs.create_project_docs.created_to_document_set', num_created: @num_created, project_name: @project_name))
        end

        it 'should include docs added' do
          @messages.should include(I18n.t('controllers.docs.create_project_docs.added_to_document_set', num_added: @num_added, project_name: @project_name))
        end

        it 'should include docs failed' do
          @messages.should include(I18n.t('controllers.docs.create_project_docs.failed_to_document_set', num_failed: @num_failed, project_name: @project_name))
        end

        it 'should include delay.save_annotations' do
          @messages.should include(I18n.t('controllers.projects.upload_zip.delay_save_annotations'))
        end

        it 'should return blank errors' do
          @errors.should be_blank
        end

        it 'project.user should be @project_user' do
          Project.find_by_name(@project_name).user.should eql(@project_user)
        end

        it 'should call save_annotations with project' do
          @project.should eql(Project.find_by_name(@project_name))
        end

        it 'should call save_annotations with doc_annotations_files' do
          @doc_annotations_files.should =~ [{name: @doc_annotations_file, path: "#{TempFilePath}#{@doc_annotations_file}"}]
        end
      end

      context 'when project which has same name exists' do
        before do
          FactoryGirl.create(:project, :user => FactoryGirl.create(:user), name: @project_name)
          @messages, @errors = Project.create_from_zip(@zip_file, @project_name, @project_user)
        end

        it 'should return blank messages' do
          @messages.should be_blank
        end

        it 'should return errors on project.name' do
          @errors[0].should include(I18n.t('errors.messages.taken'))
        end

        it 'should not call save_annotations' do
          @project.should be_nil
        end
      end

      after do
        FileUtils.rm_rf(TempFilePath)
        FileUtils.mkdir_p(TempFilePath)
      end
    end
  end

  describe 'old save_annotations' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @sourcedb = 'PMC'
      @sourceid = '100'
      @serial = 1
      @doc_annotations_file_name = "#{@sourcedb}-#{@sourceid}-#{@serial}-title.json"
      @doc_annotations_files = [{name: @doc_annotations_file_name, path: "#{TempFilePath}#{@doc_annotations_file_name}"}]
      @doc = FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid, serial: @serial)
      File.stub(:read).and_return(nil)
      File.stub(:unlink).and_return(nil)
      @denotations = 'denotations'
      @relations = 'relations'
      @text = 'text'
      @doc_params = {'denotations' => @denotations, 'relations' => @relations, 'text' => @text}
      JSON.stub(:parse).and_return(@doc_params)
      @project.stub(:save_annotations).and_return(nil)
    end

    it '' do
      @project.should_receive(:save_annotations).with({denotations: @denotations, relations: @relations, text: @text}, @project, @doc)
      Project.save_annotations(@project, @doc_annotations_files)
    end
  end

  describe 'store_annotations' do
    before do
      @text = 'text about'
      @denotations = [{"span" => {"begin" => 0, "end" => 134}, "obj" => "TOP"}, {"span" => {"begin" => 0, "end" => 134}, "obj" => "TITLE"}]
      @relations = nil
      @modifications = nil
      @annotations = {:text => @text, 
                      :denotations => @denotations, 
                      :relations => @relations, 
                      :modifications => @modifications}
      user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: user)
      @project.stub(:save_annotations).and_return(nil)
    end

    context 'when options[:delayed] == true' do
      before do
        @options = {mode: 'mode', delayed: true}
      end

      context 'when finished without errors' do
        context 'when divs.length == 1' do
          before do
            @div = FactoryGirl.create(:doc)
            @divs = [@div]
          end

          it 'should call @project.save_annotations with annotations, project, divs[0] and options' do
            @project.should_receive(:save_annotations).with(@annotations, @project, @div, @options) 
            @project.store_annotations(@annotations, @project, @divs, @options)
          end

          it 'should create project.notices with successful: true, method store_annotations' do
            @project.notices.should_receive(:create).with({successful: true, method: 'store_annotations'})
            @project.store_annotations(@annotations, @project, @divs, @options)
          end
        end

        context 'when divs.length !== 1' do
          before do
            @div_1 = FactoryGirl.create(:doc)
            @div_2 = FactoryGirl.create(:doc)
            @divs = [@div_1, @div_2]
            @denotations = [{span: {begin: 3, end: 5}}]
            @annotations = {:text => @text, 
                            :denotations => @denotations, 
                            :relations => @relations, 
                            :modifications => @modifications}
            @find_divisions = [[1, [0, 3]], [1, [2, 5]]]
            TextAlignment.stub(:find_divisions).and_return(@find_divisions)
          end

          it 'should call @project.save_annotations with annotations, project, divs[0]' do
            @project.should_receive(:save_annotations).twice
            @project.store_annotations(@annotations, @project, @divs, @options)
          end

          it 'should create project.notices with successful: true, method store_annotations' do
            @project.notices.should_receive(:create).with({successful: true, method: 'store_annotations'})
            @project.store_annotations(@annotations, @project, @divs, @options)
          end
        end
      end

      context 'when finished without errors' do
        it 'should create project.notices with successful: false, method store_annotations' do
          @project.notices.should_receive(:create).with({successful: false, method: 'store_annotations'})
          @project.store_annotations(@annotations, @project, nil, @options)
        end
      end
    end

    context 'when options[:delayed] == false' do
      before do
        @options = {mode: 'mode'}
        @div = FactoryGirl.create(:doc)
        @divs = [@div]
      end

      it 'should not create project.notices with successful: true, method store_annotations' do
        @project.notices.should_not_receive(:create).with({successful: true, method: 'store_annotations'})
        @project.store_annotations(@annotations, @project, @divs, @options)
      end
    end
  end

  describe 'add_docs_from_json' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) 
    end
    
    context 'when sourcedbs prensent' do
      before do
        @attributes = Array.new
        @docs_array = Array.new
        @project.stub(:add_docs) do |options|  
          @attributes << {sourcedb: options[:sourcedb], ids: options[:ids]}
          @docs_array << options[:docs_array]
          @options_user = options[:user]
          [1, 1, 1]
        end
        @pmc_user_1 = {:sourcedb => "PMC:user name", :sourceid => '1', :divid => 0, :text => 'body text'}
        @pmc_user_2 = {:sourcedb => "PMC:user name", :sourceid => '1', :divid => 1, :text => 'body text'} 
        @pmc_1 = {:sourceid => "1", :sourcedb => "PMC"} 
        @pmc_2 = {:sourceid => "2", :sourcedb => "PMC"} 
        @pub_med = {:sourceid => "1", :sourcedb => "PubMed"}
        @user = FactoryGirl.create(:user)
      end

      context 'when json is Array' do
        before do
          docs = [@pmc_user_1, @pmc_user_2, @pmc_1, @pmc_2, @pub_med]
          @result = @project.add_docs_from_json(docs, @user)
        end

        it 'should pass ids and sourcedb for add_docs correctly' do
          @attributes.should =~ [{sourcedb: "PMC:user name", ids: "1,1"}, {sourcedb: "PMC", ids: "1,2"}, {sourcedb: "PubMed", ids: "1"}]
        end

        it 'should count up num_created, num_added, num_failed' do
          @result.should =~ [3, 3, 3]
        end

        it 'should pass docs_array by sourcedb' do
          @docs_array.should eql([[@pmc_user_1, @pmc_user_2], [@pmc_1, @pmc_2], [@pub_med]])
        end

        it 'should passe user as user' do
          @options_user.should eql @user
        end
      end

      context 'when docs is Hash' do
        before do
          docs = @pmc_user_1
          @result = @project.add_docs_from_json(docs, @user)
        end

        it 'should pass ids and sourcedb for add_docs correctly' do
          @attributes.should =~ [{sourcedb: "PMC:user name", ids: "1"}]
        end

        it 'should count up num_created, num_added, num_failed' do
          @result.should =~ [1, 1, 1]
        end

        it 'should pass docs_array by sourcedb' do
          @docs_array.should eql([[@pmc_user_1]])
        end
      end
    end
  end
  
  describe '#add_docs' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @sourceid = '8424'
      @sourcedb = 'PMC'
      @user = FactoryGirl.create(:user, username: 'UserName')
    end 
    
    context 'when divs present' do
      context 'when sourcedb is current_users sourcedb' do
        before do
          @user_soucedb = "PMC#{Doc::UserSourcedbSeparator}#{@user.username}"
          @doc_1 = FactoryGirl.create(:doc, :sourcedb => @user_soucedb, :sourceid => @sourceid, :serial => 0)
          @doc_2 = FactoryGirl.create(:doc, :sourcedb => @user_soucedb, :sourceid => @sourceid, :serial => 1)
          @docs_array = [
            # successfully update
            {'id' => 1, 'text' => 'doc body1', 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 0},
            {'id' => 2, 'text' => 'doc body2', 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 1},
            # successfully create
            {'id' => 3, 'text' => 'doc body3', 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 2},
            # successfully update save serial(divid) record
            {'text' => 'doc body4', 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 1},
            # fail create
            {'id' => 4, 'text' => nil, 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 3},
            # fail update
            {'text' => nil, 'sourcedb' => @user_soucedb, 'sourceid' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 0}
          ]
        end

        describe 'before execute' do
          it 'project.docs should be_blank' do
            @project.docs.should be_blank
          end
        end

        describe 'after execute' do
          before do
            @result = @project.add_docs({ids: @sourceid, sourcedb: @user_soucedb, docs_array: @docs_array, user: @user})
            @project.reload
            @doc_1.reload
            @doc_2.reload
          end

          it 'should create 1 doc and update 3 times and fail 2 time' do
            @result.should eql [1, 3, 2]
          end

          it 'should update exists doc' do
            @doc_1.body == @docs_array[0]['text'] && @doc_1.sourcedb == @docs_array[0]['sourcedb'] && @doc_1.source == @docs_array[0]['source_url'] && @doc_1.serial == @docs_array[0]['divid']
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[0]['text'] && doc.sourcedb == @docs_array[0]['sourcedb'] && doc.source == @docs_array[0]['source_url'] && doc.serial == @docs_array[0]['divid']}.should be_present
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[2]['text'] && doc.sourcedb == @docs_array[2]['sourcedb'] && doc.source == @docs_array[2]['source_url'] && doc.serial == @docs_array[2]['divid']}.should be_present
          end

          it 'should update exists doc' do
            @doc_2.body == @docs_array[3]['text'] && @doc_1.sourcedb == @docs_array[3]['sourcedb'] && @doc_1.source == @docs_array[3]['source_url'] && @doc_1.serial == @docs_array[3]['divid']
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[3]['text'] && doc.sourcedb == @docs_array[3]['sourcedb'] && doc.source == @docs_array[3]['source_url'] && doc.serial == @docs_array[3]['divid']}.should be_present
          end

          it 'should add and update project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[0]['text'] && doc.sourcedb == @docs_array[0]['sourcedb'] && doc.source == @docs_array[0]['source_url'] && doc.serial == @docs_array[0]['divid']}.should be_present
          end
        end
      end

      context 'when sourcedb is not users sourcedb' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid, :serial => 0)
          FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid, :serial => 1)        
          @project.reload
        end
        
        describe 'before execute' do
          it '@project should not include @doc' do
            @project.docs.should_not include(@doc)
          end
        end   
        
        context 'when project docs not include divs.first' do
          before do
            @result = @project.add_docs({ids: @sourceid, sourcedb: @sourcedb, user: @user})
            @project.reload
          end

          it '@project should include @doc' do
            @project.docs.should include(@doc)
          end
          
          it 'should increment num_added by added docs size' do
            @result.should eql [0, Doc.find_all_by_sourcedb_and_sourceid(@sourcedb, @sourceid).size, 0]
          end        
        end

        context 'when project docs include divs.first' do
          before do
            @project.docs << @doc
            @project.reload
          end
          
          describe 'before execute' do
            it '@project should include @doc' do
              @project.docs.should include(@doc)
            end
          end        
        end        
      end
    end
     
    context 'when divs blank' do
      context 'when generate creates doc successfully' do
        context 'when sourcedb include :' do
          context 'when sourcedb username is current_users username' do
            before do
              @sourcedb = "PMC#{Doc::UserSourcedbSeparator}#{@user.username}"
              @docs_array = [
                # successfully create
                {'id' => 1, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => '123', 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'divid' => 0},
                {'id' => 2, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => '123', 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'divid' => 1},
                # fail since same sourcedb, sourceid and serial
                {'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => '123', 'source_url' => 'http://user.sourcedb/', 'divid' => 1}
              ]
              @user_soucedb_doc = FactoryGirl.create(:doc)
              @divs = [@user_soucedb_doc]
              @num_failed_use_sourcedb_docs = 2
              @project.stub(:create_user_sourcedb_docs).and_return([@divs,  @num_failed_use_sourcedb_docs])
            end

            it 'should calls create_user_sourcedb_docs with docs_array' do
              @project.should_receive(:create_user_sourcedb_docs).with(docs_array: @docs_array)
              @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
            end
            
            it 'should increment num_created' do
              @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user}).should eql([@divs.size, 0, @num_failed_use_sourcedb_docs])
            end

            it 'should create doc from docs_array' do
              @project.docs.should_not include(@user_soucedb_doc)
              @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
              @project.reload
              @project.docs.should include(@user_soucedb_doc)
            end
          end

          context 'when sourcedb username is not current_users username' do
            before do
              @other_users_username
              @sourcedb = "PMC#{Doc::UserSourcedbSeparator}#{@other_users_username}"
              @docs_array = [
                {'id' => 1, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => 123, 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'divid' => 0},
                {'id' => 2, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => 123, 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'divid' => 1},
                {'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => 123, 'source_url' => 'http://user.sourcedb/', 'divid' => 1}
              ]
              @result = @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
            end
            
            it 'should fail 3 times' do
              @result.should eql [0, 0, @docs_array.size]
            end

            it 'should not create doc by docs_array sourcedb' do
              Doc.find_all_by_sourcedb(@sourcedb).should be_blank
            end
          end
        end

        context 'when sourcedb is not user sourcedb' do
          context 'when doc_sequencer_ present' do
            before do
              @new_sourceid = 'new sourceid'
              @generated_doc_1 = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @new_sourceid, :serial => 0)
              @generated_doc_2 = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @new_sourceid, :serial => 1)
              Doc.stub(:create_divs).and_return([@generated_doc_1, @generated_doc_2])
              @result = @project.add_docs({ids: @sourceid, sourcedb: @sourcedb, docs_array: nil, user: @user})
            end
            
            pending do
              it 'should increment num_created' do
                @result.should eql [Doc.find_all_by_sourcedb_and_sourceid(@sourcedb, @new_sourceid).size, 0, 0]
              end
            end
          end

          context 'when doc_sequencer_ blank' do
            before do
              @new_sourceid = '123456'
              @docs_array = [
                # successfully create
                {'id' => 1, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => @new_sourceid, 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'divid' => 0},
                {'id' => 2, 'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => @new_sourceid, 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'divid' => 1},
                # fail since same sourcedb, sourceid and serial
                {'text' => 'doc body', 'sourcedb' => @sourcedb, 'sourceid' => @new_sourceid, 'source_url' => 'http://user.sourcedb/', 'divid' => 1}
              ]
              Doc.stub(:create_divs).and_return([@generated_doc_1, @generated_doc_2])
              @sourcedb = 'sourcedb'
              @user = FactoryGirl.create(:user, username: 'User Name')
              @user_soucedb_doc = FactoryGirl.create(:doc)
              @divs = [@user_soucedb_doc]
              @num_failed_use_sourcedb_docs = 2
              @project.stub(:create_user_sourcedb_docs).and_return([@divs,  @num_failed_use_sourcedb_docs])
            end
            
            it 'should call create_user_sourcedb_docs with docs_array and sourcedb' do
              @project.should_receive(:create_user_sourcedb_docs).with({docs_array: @docs_array, sourcedb: "#{@sourcedb}:#{@user.username}"})
              @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
            end

            it 'should increment num_created' do
              @result = @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
              @result.should eql([@divs.size, 0 , @num_failed_use_sourcedb_docs])
            end

            it 'should add create_user_sourcedb_docs as project.docs' do
              @project.docs.should_not include(@user_soucedb_doc)
              @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: @docs_array, user: @user})
              @project.docs.should include(@user_soucedb_doc)
            end
          end
        end
      end 
      
      context 'when generate crates doc unsuccessfully' do
        before do
          Doc.stub(:create_divs).and_return(nil)
          @result = @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: nil, user: @user})
        end
        
        pending do
          it 'should not increment num_failed' do
            @result.should eql [0, 0, 1]
          end
        end
      end            
    end
  end

  describe 'create_user_sourcedb_docs', elasticsearch: true do
    # TODO just assserting about call index_diff
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user))}
    let(:docs_array) { {sourcedb: ''} }

    before do
      Doc.stub(:index_diff).and_return(nil)
      Doc.any_instance.stub(:valid?).and_return(true)
    end

    it 'should call index_diff' do
      expect(Doc).to receive(:index_diff)
      project.create_user_sourcedb_docs({docs_array: docs_array})  
    end
  end

  describe 'increment_docs_projects_counter' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end

    it 'should increment doc.projects_count' do
      expect{ 
        @project.docs << @doc 
        @doc.reload
      }.to change{ @doc.projects_count }.from(0).to(1)
    end
  end

  describe 'decrement_docs_projects_counter' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project.docs << @doc 
      @doc.reload
    end

    it 'should decrement doc.projects_count' do
      expect{ 
        @project.docs.delete(@doc)
        @doc.reload
      }.to change{ @doc.projects_count }.from(1).to(0)
    end
  end

#   describe 'update_annotations_updated_at' do
#     before do
#       @doc = FactoryGirl.create(:doc)
#       @doc.stub(:update_doc_delta_index).and_return(nil)
#       @annotations_updated_at = 5.days.ago
#       @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), annotations_updated_at: @annotations_updated_at )
#       @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), annotations_updated_at: @annotations_updated_at )
#     end

#     describe 'after_add' do
#       it 'should update projects.annotations_updated_at' do
#         @project_1.docs << @doc
#         @project_2.docs << @doc
#         @project_1.annotations_updated_at.should_not eql(@annotations_updated_at)
#         @project_2.annotations_updated_at.should_not eql(@annotations_updated_at)
#       end

#     end

#     describe 'after_remove' do
#       before do
#         @project_1.docs.delete(@doc)
#         @project_2.docs.delete(@doc)
#       end

#       it 'should update projects.annotations_updated_at' do
#         @project_1.annotations_updated_at.should_not eql(@annotations_updated_at)
#         @project_2.annotations_updated_at.should_not eql(@annotations_updated_at)
#       end
#     end
#   end

  describe 'save_hdenotations' do
    let(:doc) { FactoryGirl.create(:doc, :section => 'section', :body => 'doc body') }
    let(:project) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name") }
    let(:obj_name) { 'Category' }
    let(:hdenotation) { {id: 'hid', span: {begin: 1, end: 10}, obj: obj_name } }
    let(:hdenotations) { Array.new }

    before do
      hdenotations << hdenotation
    end

    describe 'obj' do
      context 'when obj not present' do
        it 'should create obj' do
          expect{ project.save_hdenotations(hdenotations, doc) }.to change{ Obj.count }.from(0).to(1)
        end
      end

      context 'when obj present' do
        let(:obj) { FactoryGirl.create(:obj , name: obj_name) }

        before do
          obj
        end

        it 'should not create obj' do
          expect{ project.save_hdenotations(hdenotations, doc) }.not_to change{ Obj.count }.by(1)
        end
      end
    end
    
    context 'save successfully' do
      let(:denotation) { Denotation.find_by_hid(hdenotation[:id]) }

      before do
        project.save_hdenotations(hdenotations, doc)
      end

      it 'should save hdenotation[:id] as hid' do
        expect( denotation.hid ).to eql(hdenotation[:id])
      end
      
      it 'should save hdenotation[:span][:begin] as begin' do
        expect( denotation.begin ).to eql(hdenotation[:span][:begin])
      end
      
      it 'should save hdenotation[:span][:end] as end' do
        expect( denotation.end).to eql(hdenotation[:span][:end])
      end
      
      it 'should save hdenotation[:obj] as obj' do
        expect( denotation.obj ).to eql(Obj.find_by_name(hdenotation[:obj]))
      end

      it 'should add project to denotation.projects' do
        expect( denotation.projects ).to include(project)
      end

      it 'should save doc.id as doc_id' do
        expect( denotation.doc_id ).to eql(doc.id)
      end
    end

    context 'save failed' do
      let(:hdenotation) { {id: 'hid', obj: obj_name } }

      it 'should raise error' do
        expect{ project.save_hdenotations(hdenotations, doc) }.to raise_error
      end
    end
  end

  describe 'create_user_sourcedb_docs' do
    before do
      @project = FactoryGirl.build(:project, user: FactoryGirl.create(:user))  
      @docs_array = [
        {text: 'text', sourcedb: 'sdb', sourceid: 'sid', section: 'section', source_url: 'http', divid: 0},
        {text: 'text', sourcedb: 'sdb', sourceid: nil, section: 'section', source_url: 'http', divid: 0}
      ]  
    end

    context 'when options[:sourcedb] blank' do
      it 'should save doc once' do
        expect_any_instance_of(Doc).to receive(:save)
        @project.create_user_sourcedb_docs({docs_array: @docs_array})
      end

      it 'should fail once' do
        expect(@project.create_user_sourcedb_docs({docs_array: @docs_array})[1]).to eql(1)
      end

      it 'should save doc once' do
        expect{ @project.create_user_sourcedb_docs({docs_array: @docs_array}) }.to change{ Doc.count }.from(0).to(1)
      end
    end

    context 'when options[:sourcedb] prensent' do
      it 'should save doc once' do
        docs_array = [
          {text: 'text', sourcedb: 'sdb', sourceid: 'sid', section: 'section', source_url: 'http', divid: 0}
        ]  
        sourcedb = 'param sdb'
        nil.stub(:valid?).and_return(true)
        nil.stub(:save).and_return(true)
        expect(Doc).to receive(:new).with({body: docs_array[0][:text], sourcedb: sourcedb, sourceid: docs_array[0][:sourceid], section: docs_array[0][:section], source: docs_array[0][:source_url], serial: docs_array[0][:divid]})
        @project.create_user_sourcedb_docs({docs_array: docs_array, sourcedb: sourcedb})
      end
    end
  end

  describe 'save_hdenotations' do
    before do
      @doc = FactoryGirl.create(:doc, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @di = 1
      1.times do
        denotation = FactoryGirl.create(:denotation, :begin => @di, :doc_id => @doc.id)
        FactoryGirl.create(:annotations_project, project_id: @associate_project_denotations_count_1.id, annotation: denotation)
        @di += 1
      end
      @result = ave_hdenotations(@hdenotations, @associate_project_denotations_count_1, @doc) 
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

  describe 'namespaces_base' do
    before do
      @user = FactoryGirl.create(:user)
    end

    context 'when namespaces prensent' do
      context 'when prefix _base present' do
        before do
          @namespace_base = {'prefix' => '_base', 'uri' => 'base_uri'}
          namespaces = [@namespace_base, {'prefix' => 'foaf', 'uri' => 'foaf.uri'}]
          @project = FactoryGirl.create(:project, user: @user, namespaces: namespaces)
        end

        it 'should return _base hash' do
          @project.namespaces_base.should eql(@namespace_base)
        end
      end

      context 'when prefix _base blank' do
        before do
          namespaces = [{'prefix' => 'foaf', 'uri' => 'foaf.uri'}]
          @project = FactoryGirl.create(:project, user: @user, namespaces: namespaces)
        end

        it 'should return nil' do
          @project.namespaces_base.should be_nil
        end
      end
    end

    context 'when namespaces nil' do
      before do
        @project = FactoryGirl.create(:project, user: @user, namespaces: nil)
      end

      it 'should return nil' do
        @project.namespaces_base.should be_nil
      end
    end
  end

  describe 'base_uri' do
    before do
      @user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: @user)
    end

    context 'when namespaces_base present' do
      before do
        @uri = 'base_uri'
        @project.stub(:namespaces_base).and_return({'uri' => @uri} )
      end

      it 'should return uri' do
        @project.base_uri.should eql(@uri)
      end
    end

    context 'when namespaces_base blank' do
      before do
        @project.stub(:namespaces_base).and_return(nil)
      end

      it 'should return nil' do
        @project.base_uri.should be_nil
      end
    end
  end

  describe 'namespaces_prefixes' do
    before do
      @user = FactoryGirl.create(:user)
      @base = {'prefix' => '_base', 'uri' => 'base_uri'}
      @prefix_1 = {'prefix' => 'foaf', 'uri' => 'foaf_uri'}
      @prefix_2 = {'prefix' => 'xml', 'uri' => 'xml_uri'}
    end

    context 'when namespaces prensent' do
      context 'when _base present' do
        before do
          namespaces = [@base, @prefix_1, @prefix_2]
          @project = FactoryGirl.create(:project, user: @user, namespaces: namespaces)
        end

        it 'should return exept _base hash' do
          @project.namespaces_prefixes.should =~ [@prefix_1, @prefix_2]
        end
      end

      context 'when _base blank' do
        before do
          namespaces = [@prefix_1, @prefix_2]
          @project = FactoryGirl.create(:project, user: @user, namespaces: namespaces)
        end

        it 'should return prefixes' do
          @project.namespaces_prefixes.should =~ [@prefix_1, @prefix_2]
        end
      end

      context 'when _base only' do
        before do
          namespaces = [@base]
          @project = FactoryGirl.create(:project, user: @user, namespaces: namespaces)
        end

        it 'should return blank' do
          @project.namespaces_prefixes.should be_blank
        end
      end
    end

    context 'when namespaces nil' do
      before do
        @project = FactoryGirl.create(:project, user: @user, namespaces: nil)
      end

      it 'should return nil' do
        @project.namespaces_prefixes.should be_nil
      end
    end
  end
  describe 'delay_destroy' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    end

    context 'when successfully finished' do
      it 'should destroy project' do
        expect{ @project.delay_destroy }.to change{ Project.count }.from(1).to(0)
      end

      it 'should not create notice' do
        expect{ @project.delay_destroy }.not_to change{ Notice.count }.from(0).to(1)
      end
    end

    context 'when failed' do
      before do
        @project.stub(:destroy).and_raise('Error')
      end

      it 'should not destroy project' do
        expect{ @project.delay_destroy }.not_to change{ Project.count }.from(1).to(0)
      end

      it 'should create notice' do
        expect{ @project.delay_destroy }.to change{ Notice.count }.from(0).to(1)
      end
    end
  end

  describe 'update_updated_at' do
    let(:updated_at) { 10.days.ago }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), updated_at: updated_at) }

    it 'should update updated_at' do
      project.update_updated_at(nil)
      expect(project.updated_at).not_to eql(updated_at)
    end
  end

  describe 'sort_by_my_projects' do
    let (:user_id) { 1 }

    it 'should return case conditions' do
      Project.sort_by_my_projects(user_id).should eql("CASE WHEN projects.user_id = #{user_id} THEN 1 WHEN projects.user_id != #{user_id} THEN 0 END")
    end
  end
