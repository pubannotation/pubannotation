# encoding: utf-8
require 'spec_helper'

describe Project do
  let!( :user) { FactoryGirl.create(:user) }

  describe 'cleanup_namespaces' do
    before do
      @user = FactoryGirl.create(:user)
    end

    describe 'before_validate' do
      it 'should call cleanup_namespaces' do
        Project.any_instance.should_receive(:cleanup_namespaces)
        FactoryGirl.create(:project, user: @user)
      end
    end

    context 'when namespaces prensent' do
      before do
        @namespace_1 = {'prefix' => '_base', 'uri' => 'http://xmlns.com/foaf/0.1/'}
        @namespace_2 = {'prefix' => 'foaf', 'uri' => 'http://xmlns.com/foaf/0.1/'}
        @namespace_3 = {'prefix' => 'wd', 'uri' => 'http://www.wikidata.org/entity/'}
        @namespace_4 = {'prefix' => 'wd', 'uri' => ''}
        @namespace_5 = {'prefix' => '', 'uri' => ''}
        @namespace_5 = {'prefix' => '', 'uri' => 'uri'}
        namespaces = [@namespace_1, @namespace_2, @namespace_3, @namespace_4]
        @project = @user.projects.build(name: 'My Project', namespaces: namespaces)
      end

      it 'should delete prefix or uri is blank' do
        @project.cleanup_namespaces 
        @project.namespaces.should =~ [@namespace_1, @namespace_2, @namespace_3]
      end
    end
  end

  describe 'user_presence' do
    context 'when user blank' do
      before do
        @project = FactoryGirl.build(:project, user: FactoryGirl.create(:user))  
      end


      it 'should not raise user_id validation error' do
        @project.valid?
        @project.errors[:user_id].should be_blank
      end 
    end 

    context 'when user blank' do
      before do
        @project = FactoryGirl.build(:project)  
      end

      it 'should raise user_id validation error' do
        @project.valid?
        @project.errors[:user_id].should be_present
      end 
    end 
  end 

  describe 'belongs_to user' do
    before do
      @user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @user)
    end
    
    it 'project should belongs_to user' do
      @project.user.should eql(@user)
    end
  end
  
  describe 'has_and_belongs_to_many docs' do
    before(:all) do
      @doc_1 = FactoryGirl.create(:doc)
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc).id)
      @doc_1.reload
    end
    
    it 'doc.projects should include @project_1' do
      @doc_1.projects.should include(@project_1)
    end
    
    it '@project_1.docs should include @doc' do
      @project_1.docs.should include(@doc_1)
    end
    
    it 'doc.projects should include @project_2' do
      @doc_1.projects.should include(@project_2)
    end

    it '@project_2.docs should include @doc' do
      @project_2.docs.should include(@doc_1)
    end
  end

  describe 'has_and_belongs_to_many pmdocs' do
    let( :pm_doc_1 ) { FactoryGirl.create(:doc, sourcedb: 'PubMed') }
    let( :pm_doc_2 ) { FactoryGirl.create(:doc, sourcedb: 'PubMed') }
    let( :pmc_doc_2 ) { FactoryGirl.create(:doc, sourcedb: 'PMC') }
    let( :user) { FactoryGirl.create(:user) }
    let!( :project ) { FactoryGirl.create(:project, user: user) }

    before do
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pm_doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pm_doc_2.id)
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pmc_doc_2.id)
    end

    it 'should include docs sourcedb == PubMed and belongs_to project' do
      expect( project.pmdocs ).to match_array([pm_doc_1, pm_doc_2])
    end
  end

  describe 'has_and_belongs_to_many pmcdocs' do
    let( :pmc_doc_1 ) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: 'sid1', serial: 0) }
    let( :pmc_doc_2 ) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: 'sid1', serial: 1) }
    let( :pmc_doc_3 ) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: 'sid2', serial: 0) }
    let( :pm_doc_1 ) { FactoryGirl.create(:doc, sourcedb: 'PubMed') }
    let( :user) { FactoryGirl.create(:user) }
    let!( :project ) { FactoryGirl.create(:project, user: user) }

    before do
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pmc_doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pmc_doc_2.id)
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pmc_doc_3.id)
      FactoryGirl.create(:docs_project, :project_id => project.id, :doc_id => pm_doc_1.id)
    end

    it 'should include docs sourcedb == PubMed and belongs_to project' do
      expect( project.pmcdocs ).to match_array([pmc_doc_1, pmc_doc_3])
    end
  end
  
  describe 'has_and_belongs_to_many associate_projects' do
    pending do
      before do
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))

        FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_1)
        FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_2)
        FactoryGirl.create(:associate_projects_project, :project => @project_2, :associate_project => @associate_project_1)
        FactoryGirl.create(:associate_projects_project, :project => @project_3, :associate_project => @associate_project_3)
      end  
      
      it 'project.associate_projects should return associate projects' do
        @project_1.associate_projects.should eql([@associate_project_1, @associate_project_2])
      end
      
      it 'project.associate_projects should return associate projects' do
        @project_2.associate_projects.should eql([@associate_project_1])
      end
      
      it 'project.projecs should return associated projects' do
        @associate_project_1.reload
        @associate_project_1.projects.should eql([@project_1, @project_2])
      end
      
      it 'project.projecs should return associated projects' do
        @associate_project_2.reload
        @associate_project_2.projects.should eql([@project_1])
      end
    end
  end

  describe 'has_many annotations' do
    let(:project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:doc ) { FactoryGirl.create(:doc) }
    let(:denotation ) { FactoryGirl.create(:denotation, doc: doc) }
    let(:relation) { FactoryGirl.create(:relation) }
    let(:modification) { FactoryGirl.create(:relation) }

    before do
      FactoryGirl.create(:annotations_project, annotation: denotation, project: project)
      FactoryGirl.create(:annotations_project, annotation: relation, project: project)
      FactoryGirl.create(:annotations_project, annotation: modification, project: project)
    end

    it 'should include denotations, relations and modifications' do
      expect(project.annotations).to match_array([denotation, relation, modification])
    end
  end
  
  describe 'has_many denotations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, doc: FactoryGirl.create(:doc))
      FactoryGirl.create(:annotations_project, annotation: @denotation, project: @project)
      @project.reload
    end
    
    it 'project.denotations should include denotation' do
      expect(@project.denotations).to include(@denotation) 
    end
  end

  describe 'denotations after_add' do
    let( :project ) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) }
    let( :doc ) { FactoryGirl.create(:doc) }
    let( :denotation ) { FactoryGirl.create(:denotation, :doc => doc) }

    before do
      FactoryGirl.create(:annotations_project, annotation: denotation, project: project)
      project.stub(:update_updated_at).and_return(nil)
    end

    it 'should call update_updated_at when add denotations' do
      expect(project).to receive(:update_updated_at)
      project.denotations << denotation 
    end
  end
  
  describe 'has_many relations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :obj_id => 5)
      FactoryGirl.create(:annotations_project, annotation: @relation, project: @project)
    end
    
    it 'project.relations should be present' do
      @project.relations.should be_present
    end
    
    it 'project.relations should include related relation' do
      (@project.relations - [@relation]).should be_blank
    end
  end

  describe 'relations after_add' do
    let( :project ) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) }
    let( :relation ) { FactoryGirl.create(:relation, obj_id: 5) }

    before do
      project.stub(:update_updated_at).and_return(nil)
    end

    it 'should call update_updated_at when add relations' do
      expect(project).to receive(:update_updated_at)
      project.relations << relation 
    end
  end
  
  describe 'has_many modifications' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      FactoryGirl.create(:annotations_project, annotation: @denotation, project: @project)
      @modification = FactoryGirl.create(:modification, :obj => @denotation)
      FactoryGirl.create(:annotations_project, annotation: @modification, project: @project)
    end
    
    it 'project.modifications should be present' do
      @project.modifications.should be_present
    end
    
    it 'project.modifications should include related modification' do
      (@project.modifications - [@modification]).should be_blank
    end
  end

  describe 'modification after_add' do
    let( :project ) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) }
    let( :project ) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) }
    let( :doc ) { FactoryGirl.create(:doc) }
    let( :denotation ) { FactoryGirl.create(:denotation, :doc => doc) }
    let( :modification ) { FactoryGirl.create(:modification, :obj => denotation) }

    before do
      project.stub(:update_updated_at).and_return(nil)
    end

    it 'should call update_updated_at when add modifications' do
      expect(project).to receive(:update_updated_at)
      project.modifications << modification
    end
    let( :doc ) { FactoryGirl.create(:doc) }
    let( :denotation ) { FactoryGirl.create(:denotation, :doc => doc) }
    let( :modification ) { FactoryGirl.create(:modification, :obj => denotation) }

    before do
      project.stub(:update_updated_at).and_return(nil)
    end

    it 'should call update_updated_at when add modifications' do
      expect(project).to receive(:update_updated_at)
      project.modifications << modification
    end
  end
  
  describe 'has_many associate_maintainers' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @user_1 = FactoryGirl.create(:user)
      @associate_maintainer_1 = FactoryGirl.create(:associate_maintainer, 
        :user => @user_1,
        :project => @project)
      @user_2 = FactoryGirl.create(:user)
      @associate_maintainer_2 = FactoryGirl.create(:associate_maintainer, 
        :user => @user_2,
        :project => @project)
    end
    
    it 'should prensent' do
      @project.associate_maintainers.should be_present
    end
    
    it 'should prensent' do
      @project.associate_maintainers.to_a.should =~ [@associate_maintainer_1, @associate_maintainer_2]
    end
    
    it 'should destoryed when project destroyed' do
      expect{ @project.destroy }.to change{ AssociateMaintainer.count }.by(-2)
    end
  end
  
  describe 'has_many associate_maintainer_users' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @user_1 = FactoryGirl.create(:user)
      @associate_maintainer_1 = FactoryGirl.create(:associate_maintainer, 
        :user => @user_1,
        :project => @project)
      @user_2 = FactoryGirl.create(:user)
      @associate_maintainer_2 = FactoryGirl.create(:associate_maintainer, 
        :user => @user_2,
        :project => @project)
    end
    
    it 'should prensent' do
      @project.associate_maintainer_users.should be_present
    end
    
    it 'should include' do
      @project.associate_maintainer_users.to_a.should =~ [@user_1, @user_2]
    end
  end

  describe 'has_many jobs' do
    let( :project ) { FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) }
    let( :job ) { FactoryGirl.create(:job, project: project) }

    it 'should call update_updated_at when add modifications' do
      expect(project.jobs).to match_array([ job ])
    end
  end

  describe 'has_many notices' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @notice_1 = FactoryGirl.create(:notice, project: @project)
      @notice_2 = FactoryGirl.create(:notice, project: @project)
    end

    it 'should return notices belongs_to project' do
      @project.notices.to_a.should =~ [@notice_1, @notice_2]
    end
  end

  describe 'default_scope' do
    before do
      2.times do
        FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        FactoryGirl.create(:project, type: 'Sub', :user => FactoryGirl.create(:user))
      end
      @projects = Project.order('id ASC').order('name DESC')
    end

    it 'should not include type present' do
      @projects.where('type IS NOT NULL').should be_blank
    end
  end

  describe 'scope for_index' do
    let( :user ) { FactoryGirl.create(:user) }
    let( :project_accessibility_1_status_1 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 1) }
    let( :project_accessibility_1_status_2 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 2) }
    let( :project_accessibility_1_status_3 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 3) }
    let( :project_accessibility_0_status_1 ) { FactoryGirl.create(:project, user: user, accessibility: 0, status: 1) }

    before do
      @projects = Project.for_index 
    end

    it 'should include accessibility == 1 and status == 1' do
      expect( @projects ).to include(project_accessibility_1_status_1)
    end

    it 'should include accessibility == 1 and status == 2' do
      expect( @projects ).to include(project_accessibility_1_status_2)
    end

    it 'should not include accessibility == 1 and status == 3' do
      expect( @projects ).not_to include(project_accessibility_1_status_3)
    end

    it 'should not include accessibility == 0' do
      expect( @projects ).not_to include(project_accessibility_0_status_1)
    end
  end

  describe 'scope for_home' do
    let( :user ) { FactoryGirl.create(:user) }
    let( :project_accessibility_1_status_1 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 1) }
    let( :project_accessibility_1_status_2 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 2) }
    let( :project_accessibility_1_status_3 ) { FactoryGirl.create(:project, user: user, accessibility: 1, status: 3) }
    let( :project_accessibility_0_status_1 ) { FactoryGirl.create(:project, user: user, accessibility: 0, status: 1) }

    before do
      @projects = Project.for_home
    end

    it 'should include accessibility == 1 and status == 1' do
      expect( @projects ).to include(project_accessibility_1_status_1)
    end

    it 'should include accessibility == 1 and status == 2' do
      expect( @projects ).to include(project_accessibility_1_status_2)
    end

    it 'should not include accessibility == 1 and status == 3' do
      expect( @projects ).not_to include(project_accessibility_1_status_3)
    end

    it 'should not include accessibility == 0' do
      expect( @projects ).not_to include(project_accessibility_0_status_1)
    end
  end

  describe 'scope accessible' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      @accessibility_0_user_1 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_1)  
      @accessibility_1_user_1 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_1)  
      @accessibility_0_user_2 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_2)  
      @accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)
      @maintainer_project_accessibility_0_user_2 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_2)
      @maintainer_project_accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)
      FactoryGirl.create(:associate_maintainer, :project => @maintainer_project_accessibility_0_user_2, :user => @user_1)
      FactoryGirl.create(:associate_maintainer, :project => @maintainer_project_accessibility_1_user_2, :user => @user_1)
      @maintainer_project_accessibility_0_user_2.reload
      @maintainer_project_accessibility_1_user_2.reload
    end
    
    context 'when current_user present' do
      before do
        @projects = Project.accessible(@user_1)
      end
      
      it 'includes accessibility = 1 and user is not current_user' do
        @projects.should include(@accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1 and user is current_user' do
        @projects.should include(@accessibility_1_user_1)
      end
      
      it 'not includes accessibility != 1 and user is not current_user' do
        @projects.should_not include(@accessibility_0_user_2)
      end
      
      it 'includes accessibility != 1 and user is current_user' do
        @projects.should include(@accessibility_0_user_1)
      end
      
      it 'includes accessibility != 1 and user is not current_user but user is an associate maintainer' do
        @projects.should include(@maintainer_project_accessibility_0_user_2)
      end
      
      it 'includes accessibility == 1 and user is not current_user but user is an associate maintainer' do
        @projects.should include(@maintainer_project_accessibility_1_user_2)
      end
    end
    
    context 'when current_user blank' do
      before do
        @projects = Project.accessible(nil)
      end
      
      it 'includes accessibility = 1' do
        @projects.should include(@accessibility_1_user_1)
      end
      
      it 'includes accessibility = 1' do
        @projects.should include(@accessibility_1_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @projects.should_not include(@accessibility_0_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @projects.should_not include(@accessibility_0_user_1)
      end
    end
  end

  describe 'scope editable' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      # projects by @user_1 with no maintainers
      @accessibility_10_user_1 = FactoryGirl.create(:project, :accessibility => 10, :user => @user_1)  
      @accessibility_1_user_1 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_1)  
      # projects by @user_2 with no maintainers 
      @accessibility_10_user_2 = FactoryGirl.create(:project, :accessibility => 10, :user => @user_2)  
      @accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)
      # projects by @user_2 with maintainers includes @user_1
      @maintainer_project_accessibility_10_user_2 = FactoryGirl.create(:project, :accessibility => 10, :user => @user_2)
      @maintainer_project_accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)
      FactoryGirl.create(:associate_maintainer, :project => @maintainer_project_accessibility_10_user_2, :user => @user_1)
      FactoryGirl.create(:associate_maintainer, :project => @maintainer_project_accessibility_1_user_2, :user => @user_1)
      @maintainer_project_accessibility_10_user_2.reload
      @maintainer_project_accessibility_1_user_2.reload
    end
    
    context 'when current_user present' do
      before do
        @projects = Project.editable(@user_1)
      end
      
      it 'includes user is current_user and includes current_user as maintainers' do
        expect(@projects).to match_array([@accessibility_10_user_1, @accessibility_1_user_1, @maintainer_project_accessibility_10_user_2, @maintainer_project_accessibility_1_user_2])
      end
    end
    
    context 'when current_user blank' do
      before do
        @projects = Project.editable(nil)
      end
      
      it 'all of accessibility = 10' do
        expect(@projects.collect{|p| p.accessibility}.uniq).should eql([10])
      end
    end
  end

  describe 'scope mine' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      # projects by @user_1 with no maintainers
      @user_1_1 = FactoryGirl.create(:project, user: @user_1)  
      @user_1_2 = FactoryGirl.create(:project, user: @user_1)  
      # projects by @user_2 with no maintainers 
      @user_2_1 = FactoryGirl.create(:project, user: @user_2)  
      @user_2_2 = FactoryGirl.create(:project, user: @user_2)
      # projects by @user_2 with maintainers includes @user_1
      @user_2_maintainer_user_1_1 = FactoryGirl.create(:project, user: @user_2)
      @user_2_maintainer_user_2_2 = FactoryGirl.create(:project, user: @user_2)
      FactoryGirl.create(:associate_maintainer, project: @user_2_maintainer_user_1_1, user: @user_1)
      FactoryGirl.create(:associate_maintainer, project: @user_2_maintainer_user_2_2, user: @user_1)
      @user_2_maintainer_user_1_1.reload
      @user_2_maintainer_user_2_2.reload
    end
    
    context 'when current_user present' do
      before do
        @projects = Project.mine(@user_1)
      end
      
      it 'includes user is current_user and includes current_user as maintainers' do
        expect(@projects).to match_array([@user_1_1, @user_1_2, @user_2_maintainer_user_1_1, @user_2_maintainer_user_2_2])
      end
    end
    
    context 'when current_user blank' do
      before do
        @projects = Project.mine(nil)
      end
      
      it 'should return all' do
        expect(@projects).to match_array(Project.all)
      end
    end
  end

  describe 'scope top_annotations_count' do
    before(:all) do
      Project.delete_all
      @user = FactoryGirl.create(:user)
      @project_annotations_count_10_status_3_updated_1_hour_ago = FactoryGirl.create(:project, user: @user, annotations_count: 10, status: 3, updated_at: 1.hour.ago)
      @project_annotations_count_9_status_3_updated_1_hour_ago = FactoryGirl.create(:project, user: @user, annotations_count: 9, status: 3, updated_at: 1.hour.ago)
      @project_annotations_count_9_status_2_updated_1_hour_ago = FactoryGirl.create(:project, user: @user, annotations_count: 9, status: 2, updated_at: 1.hour.ago)
      @project_annotations_count_0_status_3_updated_1_minutes_ago = FactoryGirl.create(:project, user: @user, annotations_count: 2, status: 3, updated_at: 1.minute.ago)
      @project_annotations_count_0_status_3_updated_2_minutes_ago = FactoryGirl.create(:project, user: @user, annotations_count: 2, status: 3, updated_at: 2.minute.ago)
      @projects = Project.top_annotations_count
    end

    it 'should order first by annotations_count DESC' do
      expect(@projects.first).to eql(@project_annotations_count_10_status_3_updated_1_hour_ago)
    end

    it 'should order first by annotations_count DESC' do
      expect(@projects.second).to eql(@project_annotations_count_9_status_2_updated_1_hour_ago)
    end

    it 'should order second by updated_at DESC' do
      expect(@projects[3]).to eql(@project_annotations_count_0_status_3_updated_1_minutes_ago)
    end

    it 'should order third by status ASC' do
      expect(@projects[2]).to eql(@project_annotations_count_9_status_3_updated_1_hour_ago )
    end
  end

  describe 'scope top_recent' do

  end
  
  describe 'scope not_id_in' do
    before do
      Project.delete_all
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end
    
    it 'should include project_id included in project_ids' do
      Project.not_id_in([@project_1.id, @project_2.id]).should =~ [@project_3]
    end    
  end
  
  describe 'scope id_in' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end
    
    it 'should include project_id included in project_ids' do
      Project.id_in([@project_1.id, @project_2.id]).should =~ [@project_1, @project_2]
    end    
  end
  
  describe 'scope name_in' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end
    
    it 'should include project_name included in project_names' do
      Project.name_in([@project_1.name, @project_2.name]).should =~ [@project_1, @project_2]
    end    
  end

  describe 'scope order_author' do
    let!( :user) { FactoryGirl.create(:user) }
    let!( :project_author_aa ) { FactoryGirl.create(:project, user: user, author: 'AA') }
    let!( :project_author_ab ) { FactoryGirl.create(:project, user: user, author: 'AB') }
    let!( :project_author_nil ) { FactoryGirl.create(:project, user: user, author: nil) }
    
    before do
      @projects = Project.order_author
    end

    it 'should order by author ASC' do
      expect( @projects.first ).to eql(project_author_aa)
      expect( @projects.second ).to eql(project_author_ab)
      expect( @projects.last.author ).to be_nil
    end
  end

  describe 'scope order_maintainer' do
    let!( :user_aa) { FactoryGirl.create(:user, username: 'AA') }
    let!( :project_user_aa ) { FactoryGirl.create(:project, user: user_aa) }

    before do
      @projects = Project.order_maintainer
    end

    it 'should order by user.username ASC' do
      expect( @projects.first ).to eql(project_user_aa)
    end
  end

  describe 'scope order_association' do
    let!( :user) { FactoryGirl.create(:user) }
    let!( :another_user) { FactoryGirl.create(:user) }
    let!( :project_maintainer_1 ) { FactoryGirl.create(:project, user: another_user) }
    let!( :project_maintainer_2 ) { FactoryGirl.create(:project, user: another_user) }
    let!( :project_user_1 ) { FactoryGirl.create(:project, user: user) }
    let!( :project_user_2 ) { FactoryGirl.create(:project, user: user) }

    before do
      FactoryGirl.create(:associate_maintainer, user: user, project: project_maintainer_1)
      FactoryGirl.create(:associate_maintainer, user: user, project: project_maintainer_2)
      @projects = Project.order_association(user)
    end

    context 'when current_user present' do
      it '' do
        expect( @projects.limit(2) ).to match_array([project_user_1, project_user_2])
      end

      it '' do
        expect( @projects[2..3] ).to match_array([project_maintainer_1, project_maintainer_2])
      end
    end
  end

  describe 'sort_by_params' do
    context 'when sort by id' do
      before(:all) do
        Project.delete_all
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      end

      context 'when sort_order is id DESC' do
        before do
          @projects = Project.sort_by_params([['id DESC']])
        end

        it 'should sort project by sort_order' do
          @projects.first.should eql @project_3
        end

        it 'should sort project by sort_order' do
          @projects.second.should eql @project_2
        end
        
        it 'should sort project by sort_order' do
          @projects.last.should eql @project_1
        end
      end

      context 'when sort_order is id ASC' do
        before do
          @projects = Project.sort_by_params([['id ASC']])
        end

        it 'should sort project by sort_order' do
          @projects.first.should eql @project_1
        end

        it 'should sort project by sort_order' do
          @projects.second.should eql @project_2
        end
        
        it 'should sort project by sort_order' do
          @projects.last.should eql @project_3
        end
      end
    end

    context 'sort_by name' do
      before(:all) do
        Project.delete_all
        @project_1 = FactoryGirl.create(:project, name: 'Aproject',  user: FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, name: 'Bproject', user: FactoryGirl.create(:user))
        @project_3 = FactoryGirl.create(:project, name: 'aproject', user: FactoryGirl.create(:user))
        @projects = Project.sort_by_params([['LOWER(name) ASC']])
      end

      it 'should sort project by name' do
        @projects.first.should eql(@project_1)
      end

      it 'should sort project by name' do
        @projects.first.should eql(@project_1)
        @projects.second.should eql(@project_3)
      end

      it 'should sort project by name' do
        @projects.last.should eql(@project_2)
      end
    end
  end

  describe 'public?' do
    let!( :user) { FactoryGirl.create(:user) }
    let!( :project_accessibility_1 ) { FactoryGirl.create(:project, user: user, accessibility: 1) }
    let!( :project_accessibility_0 ) { FactoryGirl.create(:project, user: user, accessibility: 0) }

    context 'when accessibility == 1' do
      it 'should return true' do
        expect( project_accessibility_1.public?).to be_true
      end
    end

    context 'when accessibility == 0' do
      it 'should return false' do
        expect( project_accessibility_0.public?).to be_false
      end
    end
  end

  describe 'accessible?' do
    let!( :current_user) { FactoryGirl.create(:user) }
    let!( :another_user) { FactoryGirl.create(:user) }
    let!( :project_accessibility_1 ) { FactoryGirl.create(:project, user: another_user, accessibility: 1) }
    let!( :project_accessibility_0 ) { FactoryGirl.create(:project, user: another_user, accessibility: 0) }
    let!( :project_current_user_created) { FactoryGirl.create(:project, user: current_user, accessibility: 0) }

    context 'when accessibility == 1' do
      it 'should return true' do
        expect( project_accessibility_1.accessible?(current_user)).to be_true
      end
    end

    context 'when accessibility == 0' do
      it 'should return false' do
        expect( project_accessibility_0.accessible?(current_user)).to be_false
      end
    end

    context 'when project user == current_user' do
      it 'should return true' do
        expect( project_current_user_created.accessible?(current_user)).to be_true
      end
    end

    context 'when project user != current_user' do
      it 'should return false' do
        expect( project_accessibility_0.accessible?(current_user)).to be_false
      end
    end

    context 'when current_user.root? == true' do
      before do
        current_user.stub(:root?).and_return(true)
      end

      it 'should return true' do
        expect( project_accessibility_0.accessible?(current_user)).to be_true
      end
    end
  end

  describe 'editable?' do
    let!( :current_user) { FactoryGirl.create(:user) }
    let!( :another_user) { FactoryGirl.create(:user) }
    let!( :project_current_user_created) { FactoryGirl.create(:project, user: current_user) }
    let!( :project_current_user_maintain) { FactoryGirl.create(:project, user: another_user) }
    let!( :project_another_user_created) { FactoryGirl.create(:project, user: another_user) }

    before do
      FactoryGirl.create(:associate_maintainer, project: project_current_user_maintain, user: current_user)
    end

    context 'when current_user.prensent?' do
      context 'when current_user.root? == true' do
        before do
          current_user.stub(:root?).and_return(true)
        end

        it 'should return true' do
          expect( project_another_user_created.editable?(current_user) ).to be_true    
        end
      end

      context 'when project.user == current_user' do
        it 'should return true' do
          expect( project_current_user_created.editable?(current_user) ).to be_true    
        end
      end

      context 'when current_user is a maintainer' do
        it 'should return true' do
          expect( project_current_user_maintain.editable?(current_user) ).to be_true    
        end
      end
    end
  end

  describe 'destroyable?' do
    before do
      @project_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @project_user)
    end

    
    context 'when user.root is true' do
      before do
        @user = FactoryGirl.create(:user, root: true)
      end

      it 'should return true' do
        @project.destroyable?(@user).should be_true
      end
    end

    context 'when current_user is project.user' do
      it 'should return true' do
        @project.destroyable?(@project_user).should be_true
      end
    end
  end

  describe 'status_text' do
    context 'when status = 1' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :status => 1)
      end 
      
      it 'should return I18n released' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.released'))
      end
    end
    
    context 'when status = 2' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :status => 2)
      end 
      
      it 'should return I18n beta' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.beta'))
      end
    end

    context 'when status = 3' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :status => 3)
      end 
      
      it 'should return I18n developing' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.developing'))
      end
    end
  end
  
  describe 'accessibility_text' do
    context 'when accessibility = 1' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 1)
      end 
      
      it 'should return I18n released' do
        @project.accessibility_text.should eql(I18n.t('activerecord.options.project.accessibility.public'))
      end
    end
    
    context 'when accessibility = 2' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 2)
      end 
      
      it 'should return I18n beta' do
        @project.accessibility_text.should eql(:Private)
      end
    end
  end
  
  describe 'process_text' do
    context 'when process == 1' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :process => 1)
      end 
      
      it 'should return I18n manual' do
        @project.process_text.should eql(I18n.t('activerecord.options.project.process.manual'))
      end
    end
    
    context 'when process == 2' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :process => 2)
      end 
      
      it 'should return I18n automatic' do
        @project.process_text.should eql(I18n.t('activerecord.options.project.process.automatic'))
      end
    end
  end
  
  describe 'self.order_by' do
    context 'pmdocs_count' do
      before(:all) do
        Project.delete_all
        @project_pmdocs_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 1, :accessibility => 1)
        @project_pmdocs_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 2, :accessibility => 1)
        @project_pmdocs_4 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 4, :accessibility => 1)
        @projects = Project.order_by(Project, 'pmdocs_count', nil)
      end
      it 'project which has 4 pmdocs should be @projects[0]' do
        @projects[0].should eql(@project_pmdocs_4)
      end
      
      it 'project which has 2 pmdocs should be @projects[1]' do
        @projects[1].should eql(@project_pmdocs_2)
      end
  
      it 'project which has 1 pmdocs should be @projects[2]' do
        @projects[2].should eql(@project_pmdocs_1)
      end
    end
  
    context 'pmcdocs_count' do
      before(:all) do
        Project.delete_all
        @project_pmcdocs_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmcdocs_count => 1, :accessibility => 1)
        @project_pmcdocs_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmcdocs_count => 2, :accessibility => 1)
        @project_pmcdocs_4 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmcdocs_count => 4, :accessibility => 1)
        @projects = Project.order_by(Project, 'pmcdocs_count', nil)
      end
      
      it 'project which has 4 pmcdocs should be @projects[0]' do
        @projects[0].should eql(@project_pmcdocs_4)
      end
      
      it 'project which has 2 pmcdocs should be @projects[1]' do
        @projects[1].should eql(@project_pmcdocs_2)
      end
  
      it 'project which has 1 pmcdocs should be @projects[2]' do
        @projects[2].should eql(@project_pmcdocs_1)
      end
    end
  
    context 'denotations_count' do
      before(:all) do
        Project.delete_all
        @project_2_denotations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :denotations_count => 2, :accessibility => 1)
        @project_1_denotations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :denotations_count => 1, :accessibility => 1)
        @project_0_denotations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :denotations_count => 0, :accessibility => 1)
        @projects = Project.order_by(Project, 'denotations_count', nil)
      end
      
      it 'project which has 2 denotations should be @projects[0]' do
        @projects[0].should eql(@project_2_denotations)
      end
      
      it 'project which has 1 denotations should be @projects[1]' do
        @projects[1].should eql(@project_1_denotations)
      end
      
      it 'project which has 0 denotations should be @projects[2]' do
        @projects[2].should eql(@project_0_denotations)
      end
    end
  
    context 'not match' do
      before(:all) do
        Project.delete_all
        @project_name_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => '00001', :accessibility => 1)
        @project_name_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => '00002', :accessibility => 1)
      end
      
      it 'order by else should return accessible and orde by name ASC' do
        Project.order_by(Project, nil, nil).first.should eql(@project_name_1)
      end
    end 
  end 

  describe 'increment_docs_counter' do
    let( :project) { FactoryGirl.create(:project, user: user) }
    let( :associate_project) { FactoryGirl.create(:project, user: user) }
    let( :pmc_doc) { FactoryGirl.create(:doc, sourcedb: 'PMC', serial: 0, sourceid: 'increment_docs_counter') }
    let( :pm_doc) { FactoryGirl.create(:doc, sourcedb: 'PubMed', sourceid: 'increment_docs_counter') }

    before do
      project.stub(:projects).and_return([ associate_project ])
      project.reload
    end

    context 'when doc.sourcedb == PMC && doc.serial == 0' do
      it 'should increment_counter' do
        Project.should_receive(:increment_counter).with(:pmcdocs_count, project.id)
        Project.should_receive(:increment_counter).with(:pmcdocs_count, associate_project.id)
        project.increment_docs_counter(pmc_doc)
      end
    end

    context 'when doc.sourcedb == PubMed' do
      it 'should increment_counter' do
        Project.should_receive(:increment_counter).with(:pmdocs_count, project.id)
        Project.should_receive(:increment_counter).with(:pmdocs_count, associate_project.id)
        project.increment_docs_counter(pm_doc)
      end
    end
  end
  
  describe 'update_delta_index' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :doc ) { FactoryGirl.create(:doc) }

    it 'should save doc' do
      expect( doc ).to receive(:save)
      project.update_delta_index(doc)
    end
  end

  describe 'increment_docs_projects_counter' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :doc ) { FactoryGirl.create(:doc) }
    
    it 'should increment_counter :projects_count' do
      expect(Doc).to receive(:increment_counter).with(:projects_count, doc.id)
      project.increment_docs_projects_counter(doc)
    end
  end

  describe 'decrement_docs_counter' do
    let( :project) { FactoryGirl.create(:project, user: user) }
    let( :associate_project) { FactoryGirl.create(:project, user: user) }
    let( :pmc_doc) { FactoryGirl.create(:doc, sourcedb: 'PMC', serial: 0, sourceid: 'decrement_docs_counter') }
    let( :pm_doc) { FactoryGirl.create(:doc, sourcedb: 'PubMed', sourceid: 'decrement_docs_counter') }

    before do
      project.stub(:projects).and_return([ associate_project ])
      project.reload
    end

    context 'when doc.sourcedb == PMC && doc.serial == 0' do
      it 'should decrement_counter' do
        Project.should_receive(:decrement_counter).with(:pmcdocs_count, project.id)
        Project.should_receive(:decrement_counter).with(:pmcdocs_count, associate_project.id)
        project.decrement_docs_counter(pmc_doc)
      end
    end

    context 'when doc.sourcedb == PubMed' do
      it 'should decrement_counter' do
        Project.should_receive(:decrement_counter).with(:pmdocs_count, project.id)
        Project.should_receive(:decrement_counter).with(:pmdocs_count, associate_project.id)
        project.decrement_docs_counter(pm_doc)
      end
    end
  end

  describe 'decrement_docs_projects_counter' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :doc ) { FactoryGirl.create(:doc) }
    
    it 'should decrement_counter :projects_count' do
      expect(Doc).to receive(:decrement_counter).with(:projects_count, doc.id)
      expect(doc).to receive(:reload)
      project.decrement_docs_projects_counter(doc)
    end
  end

  describe 'update_annotations_updated_at' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :doc ) { FactoryGirl.create(:doc) }
    let!( :annotations_updated_at) { '2016-01-01' }

    before(:all) do
      DateTime.stub(:now).and_return(annotations_updated_at)
    end
    
    it 'should increment_counter :projects_count' do
      expect(project).to receive(:update_attribute).with(:annotations_updated_at, annotations_updated_at)
      project.update_annotations_updated_at(doc)
    end
  end

  describe 'associate_maintainers_addable_for?' do
    context 'when new project' do
      before do
        @project_user = FactoryGirl.create(:user)
        @project = Project.new
      end
      
      context 'when current_user is project.user' do
        it 'should return true' do
          @project.associate_maintainers_addable_for?(@project_user).should be_true
        end
      end
    end

    context 'when saved project' do
      before do
        @project_user = FactoryGirl.create(:user)
        @project = FactoryGirl.create(:project, :user => @project_user)
        @associate_maintainer_user = FactoryGirl.create(:user)
        FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
      end
      
      context 'when current_user is project.user' do
        it 'should return true' do
          @project.associate_maintainers_addable_for?(@project_user).should be_true
        end
      end
      
      context 'when current_user is not project.user' do
        it 'should return false' do
          @project.associate_maintainers_addable_for?(@associate_maintainer_user).should be_false
        end
      end
    end
  end
  
  describe 'build_associate_maintainers' do
    context 'when usernames present' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @user_1 = FactoryGirl.create(:user)
        @user_2 = FactoryGirl.create(:user)
        @project.build_associate_maintainers([@user_1.username, @user_2.username])
      end
      
      it 'should associate @project.maintainers' do
       associate_maintainer_users = @project.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
       associate_maintainer_users.should =~ [@user_1, @user_2]
      end
    end

    context 'when usernames dupliticated' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @user_1 = FactoryGirl.create(:user)
        @project.build_associate_maintainers([@user_1.username, @user_1.username, @user_1.username])
      end
      
      it 'should associate @project.maintainers once' do
       associate_maintainer_users = @project.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
       associate_maintainer_users.should =~ [@user_1]
      end
    end
  end
  
  describe 'add_associate_projects' do
    before do
      @current_user = FactoryGirl.create(:user)
      @user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :user => FactoryGirl.create(:user))
      @associate_project_have_no_associate_projects = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 1)
      @associated_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 1)
      @associate_project_have_associate_projects_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 1)
      @associate_project_have_associate_projects_1.associate_projects << @associated_project
      @associate_project_have_associate_projects_1.reload      
      @associate_project_have_associate_projects_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 1)
      @associate_project_have_associate_projects_2.associate_projects << @associated_project
      @associated_project_unaccessible = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :accessibility => 2, :user => @user)
      @associate_project_have_associate_projects_2.associate_projects << @associated_project_unaccessible
      @associate_project_have_associate_projects_2.reload  
    end

    context 'when params[:associate_projects] present' do
      context 'when params[:associate_projects][:import] present' do
        context 'when params[:associate_projects][:import] is true' do
          context 'when associate project have associate_projects' do
            context 'when project does not have associate_projects' do
              before do
                @project.add_associate_projects(
                  {
                        :name => {
                          '0' => @associate_project_have_no_associate_projects.name, 
                          '1' => @associate_project_have_associate_projects_1.name,
                          '2' => @associate_project_have_no_associate_projects.name,
                          '3' => @associate_project_have_associate_projects_2.name
                        },
                        :import => {
                          '0' => 'true',
                          '1' => 'true',
                          '2' => 'true',
                          '3' => 'true'
                        }
                  }, @current_user          
                )
                @project.reload
              end
              
              it 'should associate projects associated associate projects once only' do
                @project.associate_projects.to_a.should =~ [
                  @associate_project_have_no_associate_projects, 
                  @associate_project_have_associate_projects_1, 
                  @associated_project, 
                  @associate_project_have_associate_projects_2
                ]
              end
            end

            context 'when project have associate_projects included in associate_projects.associate_projects' do
              before do
                @project.associate_projects << @associated_project
                @project.reload
                @project.add_associate_projects(
                  {
                        :name => {
                          '0' => @associate_project_have_no_associate_projects.name, 
                          '1' => @associate_project_have_associate_projects_1.name,
                          '2' => @associate_project_have_no_associate_projects.name,
                          '3' => @associate_project_have_associate_projects_2.name
                        },
                        :import => {
                          '0' => 'true',
                          '1' => 'true',
                          '2' => 'true',
                          '3' => 'true'
                        }
                  }, @current_user          
                )
                @project.reload
              end
              
              it 'should associate projects associated associate projects once only' do
                @project.associate_projects.to_a.should =~ [
                  @associate_project_have_no_associate_projects, 
                  @associate_project_have_associate_projects_1, 
                  @associated_project, 
                  @associate_project_have_associate_projects_2
                ]
              end
            end
          end

          context 'when associate project does not have associate_projects' do
            before do
              @project.add_associate_projects(
                {
                      :name => {
                        '0' => @associate_project_have_no_associate_projects.name, 
                        '1' => @associated_project.name
                      },
                      :import => {
                        '0' => 'true',
                        '1' => 'true'
                      }
                }, @current_user          
              )
              @project.reload
            end
            
            it 'should associate associate projects' do
              @project.associate_projects.to_a.should =~ [
                @associate_project_have_no_associate_projects, 
                @associated_project
              ]
            end
          end
        end
      end

      context 'when params[:associate_projects][:import] blank' do
        before do
          @project.add_associate_projects(
            {
                  :name => {
                    '0' => @associate_project_have_no_associate_projects.name, 
                    '1' => @associate_project_have_associate_projects_1.name,
                    '2' => @associate_project_have_no_associate_projects.name,
                    '3' => @associate_project_have_associate_projects_2.name
                  }
            }, @current_user          
          )
          @project.reload
        end
        
        it 'should not associate projects associated associate projects' do
          @project.associate_projects.to_a.should =~ [
            @associate_project_have_no_associate_projects, 
            @associate_project_have_associate_projects_1, 
            @associate_project_have_associate_projects_2
          ]
        end
      end
    end

    context 'when params[:associate_projects] blank' do
      before do
        @result = @project.add_associate_projects(nil, @current_user)
      end
      
      it 'should do nothinc' do
        @result.should be_nil
      end
    end
  end

  describe 'associate_project_ids' do
    context 'when saved project' do
      before do
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_4 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
  
        FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_1)
        FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_2)
        FactoryGirl.create(:associate_projects_project, :project => @project_2, :associate_project => @associate_project_1)
        FactoryGirl.create(:associate_projects_project, :project => @project_3, :associate_project => @associate_project_3)
        @project_1.reload
        @project_2.reload
        @project_3.reload
        @project_4.reload
        @associate_project_1.reload
        @associate_project_2.reload
        @associate_project_3.reload
      end
      
      context 'when have associate projects' do
        before do
          @ids = @project_1.associate_project_ids  
        end
        
        it 'should return associate project ids' do
          @ids.should =~ [@associate_project_1.id, @associate_project_2.id]
        end
      end
      
      context 'when does not have associate projects' do
        before do
          @ids = @project_4.associate_project_ids  
        end
        
        it 'should be blank' do
          @ids.should be_blank
        end
      end
    end
    
    context 'when new project' do
      before do
        @project = Project.new
      end
      
      it 'should return blank array' do
        @project.associate_project_ids.should be_blank
      end
    end
  end
  
  describe 'self_id_and_associate_project_ids' do
    context 'when saved project' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_ids = ['A', 'B']
        @project.stub(:associate_project_ids).and_return(@associate_project_ids)
      end
      
      it 'should return associate_project_ids and self id' do
        @project.self_id_and_associate_project_ids.should =~ @associate_project_ids << @project.id
      end
    end

    context 'when new project' do
      before do
        @project = Project.new
      end
      
      it 'should return nil' do
        @project.self_id_and_associate_project_ids.should be_nil
      end
    end
  end
  
  describe 'self_id_and_associate_project_and_project_ids' do
    context 'when saved project' do
      context 'when associate_project_and_project_ids present' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @associate_project_ids = ['A', 'B']
          @project.stub(:associate_project_and_project_ids).and_return(@associate_project_ids)
        end
        
        it 'should return associate_project_ids and self id' do
          @project.self_id_and_associate_project_and_project_ids.should =~ @associate_project_ids << @project.id
        end
      end

      context 'when associate_project_and_project_ids blank' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @associate_project_ids = [0]
          @project.stub(:associate_project_and_project_ids).and_return(@associate_project_ids)
        end
        
        it 'should return associate_project_ids and self id' do
          @project.self_id_and_associate_project_and_project_ids.should =~ @associate_project_ids << @project.id
        end
      end
    end

    context 'when new project' do
      before do
        @project = Project.new
      end
      
      it 'should return nil' do
        @project.self_id_and_associate_project_and_project_ids.should be_nil
      end
    end
  end
  
  describe 'project_ids' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))

      FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_1)
      FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_2)
      FactoryGirl.create(:associate_projects_project, :project => @project_2, :associate_project => @associate_project_1)
      @project_1.reload
      @project_2.reload
      @associate_project_1.reload
      @associate_project_2.reload
      @associate_project_3.reload
    end
    
    context 'when have projects' do
      it 'should return project ids' do
        @associate_project_1.project_ids.should =~ [@project_1.id, @project_2.id]
      end
    end
    
    context 'when does not have projects' do
      it 'should be blank' do
        @project_1.project_ids.should be_blank
      end
    end
  end
  
  describe 'associate_project_and_project_ids' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_4 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))

      FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_1)
      FactoryGirl.create(:associate_projects_project, :project => @project_1, :associate_project => @associate_project_2)
      FactoryGirl.create(:associate_projects_project, :project => @project_2, :associate_project => @associate_project_1)
      FactoryGirl.create(:associate_projects_project, :project => @project_2, :associate_project => @project_1)
      FactoryGirl.create(:associate_projects_project, :project => @project_3, :associate_project => @associate_project_3)
      @project_1.reload
      @project_2.reload
      @project_3.reload
      @project_4.reload
      @associate_project_1.reload
      @associate_project_2.reload
      @associate_project_3.reload
    end
    
    context 'when associate_projects and projects present' do
      it 'should return associate_project_ids and project_ids' do
        @project_1.associate_project_and_project_ids.should =~ [@associate_project_1.id, @associate_project_2.id, @project_2.id]
      end
    end
    
    context 'when projects present' do
      it 'should return project_ids' do
        @associate_project_1.associate_project_and_project_ids.should =~ [@project_1.id, @project_2.id]
      end
    end
    
    context 'when associate_projects present' do
      it 'should return associate_project_ids' do
        @project_2.associate_project_and_project_ids.should =~ [@associate_project_1.id, @project_1.id]
      end
    end
    
    context 'when associate_projects and projects blank' do
      it 'should return default value' do
        @project_4.associate_project_and_project_ids.should eql([0])
      end
    end
  end
  
  describe 'associatable_project_ids' do
    before do
      @accessible_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @accessible_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @un_accessible = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @not_id_in = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @current_user = FactoryGirl.create(:user)
    end
    
    context 'when new record' do
      before do
        Project.stub(:accessible).and_return([@accessible_1, @accessible_2])
        @project = Project.new
      end
      
      it 'should return Project.accessible project ids' do
        @project.associatable_project_ids(@current_user).should =~ [@accessible_1.id, @accessible_2.id]
      end
    end
    
    context 'when saved record' do
      before do
        Project.stub(:not_id_in).and_return([@not_id_in])
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      end
      
      it 'should return Project.accessible(current_user).not_id_in()' do
        @project.associatable_project_ids(@current_user).should =~ [@not_id_in.id]
      end
    end
  end
  
  describe 'increment_counters' do
    before do
      @project = FactoryGirl.create(:project, user: user, pmdocs_count: 1, pmcdocs_count: 1, denotations_count: 1, denotations_count: 1, relations_count: 1)
      @associate_project = FactoryGirl.create(:project, user: user)
      @associate_project.stub_chain(:pmdocs, :count).and_return(1)
      @associate_project.stub_chain(:pmcdocs, :count).and_return(2)
      @associate_project.stub_chain(:denotations, :count).and_return(3)
      @associate_project.stub_chain(:relations, :count).and_return(4)
      @project.increment_counters(@associate_project)
      @project.reload
    end
    
    it 'should increment pmdocs_count by associate_project.pmdocs.count' do
      expect(@project.pmdocs_count).to eql(2)
    end
    
    it 'should increment pmcdocs_count by associate_project.pmcdocs.count' do
      expect(@project.pmcdocs_count).to eql(3)
    end
    
    it 'should increment denotations_count by associate_project.denotations.count' do
      expect(@project.denotations_count).to eql(4)
    end
    
    it 'should increment relations_count associate_project.relations.count' do
      expect(@project.relations_count).to eql(5)
    end
  end

  describe 'increment_pending_associate_projects_count' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :associate_project ) { FactoryGirl.create(:project, user: user) }

    it 'should call increment_counter' do
      expect(Project).to receive(:increment_counter).with(:pending_associate_projects_count, project.id)
      project.increment_pending_associate_projects_count(associate_project)
    end
  end

  describe 'copy_associate_project_relational_models' do
    let!( :project ) { FactoryGirl.create(:project, user: user) }
    let!( :associate_project ) { FactoryGirl.create(:project, user: user) }
    let!( :doc) { FactoryGirl.create(:doc) }
    let!( :denotation) { FactoryGirl.create(:denotation, doc_id: 1) }
    let!( :relation) { FactoryGirl.create(:relation) }

    before do
      associate_project.stub(:docs).and_return([doc])
      associate_project.stub(:denotations).and_return([denotation])
      associate_project.stub(:relations).and_return([relation])
    end
    
    context 'when associate_project.docs present' do
      it 'should add associate_project.docs to self.docs' do
        project.copy_associate_project_relational_models(associate_project)
        project.reload
        expect( project.docs ).to include(doc)
      end
    end
    
    context 'when associate_project.denotations present' do
      context 'when same_denotation.blank' do
        it 'should copy associate_project.denotations to self.denotations' do
          expect{ project.copy_associate_project_relational_models(associate_project) }.to change{ project.denotations.count }.by(1)
        end
      end
    end
    
    context 'when associate_project.relations present' do
      context 'when same_denotation.blank' do
        it 'should copy associate_project.relations to self.relations' do
          expect{ project.copy_associate_project_relational_models(associate_project) }.to change{ project.relations.count }.by(1)
        end
      end
    end
  end

  describe 'decrement_counters' do
    before do
      @pmdocs_count = 1
      @pmcdocs_count = 2
      @denotations_count = 3
      @relations_count = 4
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), pmdocs_count: @pmdocs_count, pmcdocs_count: @pmcdocs_count, denotations_count: @denotations_count, relations_count: @relations_count)
      @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_project.stub(:pmdocs).and_return([1])
      @associate_project.stub(:pmcdocs).and_return([1])
      @associate_project.stub(:denotations).and_return([1])
      @associate_project.stub(:relations).and_return([1])
      @project.reload
      @project.decrement_counters(@associate_project)
      @project.reload
    end

    it 'should decrement project.pmdocs_count' do
      @project.pmdocs_count.should eql(@pmdocs_count - 1) 
    end

    it 'should decrement project.pmcdocs_count' do
      @project.pmcdocs_count.should eql(@pmcdocs_count - 1) 
    end
    
    it 'should decrement project.denotations_count' do
      @project.denotations_count.should eql(@denotations_count - 1) 
    end

    it 'should decrement project.relations_count' do
      @project.relations_count.should eql(@relations_count - 1) 
    end
  end
  
  describe 'get_annotations_count' do
    let!( :project ) { FactoryGirl.create(:project, user: user, annotations_count: 5) }
    let!( :doc) { FactoryGirl.create(:doc) }

    context 'when doc.nil' do
      it 'should return self.denotations_count' do
        expect( project.get_annotations_count(nil, nil) ).to eql(project.annotations_count) 
      end
    end

    context 'when doc.present' do
      context 'when span.nil' do
        let!(:doc_denotations_count) { 4 }
        let!(:subcatrels_count) { 6 }
        let!(:catmods_count) { 8 }
        let!(:subcatrelmods_count) { 10 }

        before do
          doc.stub_chain(:denotations, :where, :count).and_return(doc_denotations_count)
          doc.stub_chain(:subcatrels, :where, :count).and_return(subcatrels_count)
          doc.stub_chain(:catmods, :where, :count).and_return(catmods_count)
          doc.stub_chain(:subcatrelmods, :where, :count).and_return(subcatrelmods_count)
        end

        it 'should return doc.denotations, subcatrels and catmods' do
          expect( project.get_annotations_count(doc, nil) ).to eql(doc_denotations_count + subcatrels_count + catmods_count + subcatrelmods_count) 
        end
      end

      context 'when span.present' do
        let!(:hdenotations_size) { 4 }
        let!(:hrelations_size) { 6 }
        let!(:hmodifications_size) { 8 }

        before do
          doc.stub_chain(:hdenotations, :collect).and_return([])
          doc.stub_chain(:hdenotations, :size).and_return(hdenotations_size)
          doc.stub_chain(:hrelations, :collect).and_return([])
          doc.stub_chain(:hrelations, :size).and_return(hrelations_size)
          doc.stub_chain(:hmodifications, :size).and_return(hmodifications_size)
        end

        it 'should return doc.hdenotations, hrelations and hmodifications' do
          expect( project.get_annotations_count(doc, 'span') ).to eql(hdenotations_size + hrelations_size + hmodifications_size) 
        end
      end
    end
  end
  
  describe '#annotations_collection' do
    before do
      @doc_1 = FactoryGirl.create(:doc)
      @doc_2 = FactoryGirl.create(:doc)
      @doc_1_hannotations = 'hannotations_1'
      @doc_1.stub(:hannotations).and_return(@doc_1_hannotations)
      @doc_2_hannotations = 'hannotations_2'
      @doc_2.stub(:hannotations).and_return(@doc_2_hannotations)

      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end
    
    context 'when project.docs present' do
      before do
        @project.docs << @doc_1 << @doc_2
      end
      
      context 'when encodin != ascii' do
        it 'should return annotations_collection' do
          @project.annotations_collection(nil).should eql([@doc_1_hannotations, @doc_2_hannotations])
        end
      end
      
      context 'when encodin == ascii' do
        it 'should call set_ascii_body' do
          @doc_1.should_receive(:set_ascii_body)
          @doc_2.should_receive(:set_ascii_body)
          @project.annotations_collection('ascii').should eql([@doc_1_hannotations, @doc_2_hannotations])
        end
      end
    end
    
    context 'when project.docs blank' do
      it 'should return blank array' do
        @project.annotations_collection(nil).should be_blank
      end
    end
  end

  describe 'json' do
    before do
      # user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: user)
      @maintainer = 'Maintainer1'
      @project.stub(:maintainer).and_return(@maintainer)
    end

    it 'should return @project as json except specific columns and include maintainer' do
      @project.json.should eql("{\"accessibility\":null,\"annotations_count\":0,\"annotations_updated_at\":\"#{@project.annotations_updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"annotations_zip_downloadable\":#{@project.annotations_zip_downloadable},\"author\":null,\"bionlpwriter\":null,\"created_at\":\"#{@project.created_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"denotations_count\":#{@project.denotations_count},\"description\":null,\"editor\":null,\"id\":#{@project.id},\"impressions_count\":#{@project.impressions_count},\"license\":null,\"name\":\"#{ @project.name }\",\"namespaces\":null,\"process\":null,\"rdfwriter\":null,\"reference\":null,\"relations_count\":#{@project.relations_count},\"sample\":null,\"status\":null,\"updated_at\":\"#{@project.updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"viewer\":null,\"xmlwriter\":null,\"maintainer\":\"#{@maintainer}\"}")
    end
  end

  describe 'has_doc?' do
    
  end

  ## Method order
  describe 'save_hdenotations' do
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:doc) { FactoryGirl.create(:doc) }
    let(:hdenotation) { {id: 'id', span: {begin: 0, end: 5}, obj: 'Protain'} }
    let(:hdenotations) { [hdenotation] }
    
    it 'should create obj' do
      project.save_hdenotations(hdenotations, doc)
      expect( Obj.find_by_name(hdenotation[:obj])).to be_present
    end

    context 'denotation saved successfully' do
      it 'should create denotation' do
        expect{ project.save_hdenotations(hdenotations, doc) }.to change{ Denotation.count }.by(1)
      end

      it 'should add denotations as project.annotations' do
        expect{ project.save_hdenotations(hdenotations, doc) }.to change{ project.annotations.count }.by(1)
        expect{ project.save_hdenotations(hdenotations, doc) }.to change{ AnnotationsProject.count }.by(1)
      end
    end

    context 'denotation saved unsuccessfully' do
      let(:hdenotation) { {id: 'id', span: {begin: 'aaa', end: 'end'}, obj: 'Protain'} }
      let(:hdenotations) { [hdenotation] }
      
      it 'should raise error' do
        expect{ project.save_hdenotations(hdenotations, doc) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'save_hrelations' do
    let!(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let!(:doc) { FactoryGirl.create(:doc) }
    let!(:denotation) { FactoryGirl.create(:denotation, doc: doc) }
    let!(:obj_type) { 'Denotation' }
    let!(:hrelation ) { {id: 'hidA', pred: 'SaveHrel', subj: 'Denotation', subj_id: denotation.id, obj: obj_type} }
    let!(:hrelations ) { [hrelation] }

    it 'should add project.annotations' do
      expect{ project.save_hrelations(hrelations, doc) }.to change{ project.annotations.count }.by(1)    
    end
    
    it 'should set pred' do
      project.save_hrelations(hrelations, doc)
      expect( project.annotations.last.pred_id ).to eql( Pred.find_by_name(hrelation[:pred]).id )    
    end

    it 'should set subj_type and subj_id' do
      project.save_hrelations(hrelations, doc)
      expect( project.annotations.last.subj_type ).to eql(hrelation[:subj])    
      expect( project.annotations.last.subj_id ).to eql(hrelation[:subj_id])
    end

    it 'should set obj_type and obj_id' do
      project.save_hrelations(hrelations, doc)
      expect( project.annotations.last.obj_type).to eql('Obj')    
      expect( project.annotations.last.obj_id).to eql(Obj.find_by_name(hrelation[:obj]).id)
    end

    it 'should create relation' do
      expect{ project.save_hrelations(hrelations, doc) }.to change{ Relation.count }.by(1)
    end
  end

  describe 'save_hmodifications' do
    let!(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let!(:doc) { FactoryGirl.create(:doc) }
    let!(:denotation ) { FactoryGirl.create(:denotation, doc: doc, hid: 'Denotation') }
    let!(:hmodification ) { {id: 'hidA', pred: 'SaveHrel', obj: 'Relation', subj: 'Denotation', subj_id: denotation.id} }
    let!(:hmodifications ) { [hmodification] }

    it 'should create Modification' do
      expect{ project.save_hmodifications(hmodifications, doc) }.to change{ Modification.count }.by(1)
    end

    context 'when hmodification[:pred].prensent' do
      it 'should set pred_id' do
        project.save_hmodifications(hmodifications, doc)
        expect( Pred.find_by_name(hmodification[:pred]) ).to be_present
      end
    end

    context 'when hmodifications[:obj] present' do
      context 'when hmodifications[:obj] match /^R/' do
        let!(:subcatrel ) { FactoryGirl.create(:relation, obj: denotation, subj_type: 'Annotation', subj_id: denotation.id, hid: hmodification[:obj] ) }
        let!(:annotations_project) { FactoryGirl.create(:annotations_project, project: project, annotation: subcatrel) }
        let!(:pred) { FactoryGirl.create(:pred, name: hmodification[:pred]) }

        it 'should set hmodification[:obj] as obj_type' do
          project.save_hmodifications(hmodifications, doc)
          expect( Modification.find_by_obj_type(hmodification[:obj]) ).to be_present
        end
      end

      context 'when hmodification[:obj].prensent' do
        context 'when hmodifications[:obj] not match /^R/' do
          let!(:hmodification ) { {id: 'hidA', pred: 'SaveHrel', obj: 'Denotation', subj: 'Denotation', subj_id: denotation.id} }
          let!(:hmodifications ) { [hmodification] }
          let!(:subcatrel ) { FactoryGirl.create(:relation, obj: denotation, subj_type: 'Annotation', subj_id: denotation.id, hid: hmodification[:obj] ) }
          let!(:annotations_project) { FactoryGirl.create(:annotations_project, project: project, annotation: subcatrel) }
          let!(:project_denotation) { FactoryGirl.create(:annotations_project, project: project, annotation: denotation) }
          
          before do
            project.reload
          end

          it 'should set hmodification[:obj] as obj_type' do
            project.save_hmodifications(hmodifications, doc)
            expect( Modification.find_by_obj_type(hmodification[:obj]) ).to be_present
          end
        end
      end
    end
  end

  describe 'save_annotations' do
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:annotations) { {text: 'text'} }
    let(:doc) { FactoryGirl.create(:doc) }
    let(:align_denotations) { 'align_denotations' }
    let(:save_hdenotations) { 'save_hdenotations' }
    let(:save_hrelations) { 'save_hrelations' }
    let(:save_hmodifications) { 'save_hmodifications' }

    before do
      project.stub(:delete_annotations).and_return(nil)
      project.stub(:align_denotations).and_return(align_denotations)
      project.stub(:save_hdenotations).and_return(save_hdenotations)
      project.stub(:save_hrelations).and_return(save_hrelations)
      project.stub(:save_hmodifications).and_return(save_hmodifications)
    end

    context 'when doc blank' do
      it 'should raise error' do
        expect{ project.save_annotations('annotations', nil) }.to raise_error
      end
    end

    context 'when opens present && options[:mode] != add' do
      it 'should call delete_annotations' do
        expect(project).to receive(:delete_annotations).with(doc)
        project.save_annotations(annotations, doc, {mode: :other})
      end
    end

    context 'when annotations[:denotations] nil' do
      it 'should return doc.body as annotations[:text]' do
        expect( project.save_annotations(annotations, doc, {})[:text] ).to eql( doc.body ) 
      end
    end

    context 'when annotations[:denotations] present' do
      let(:annotations) { {text: 'text', denotations: 'denotations'} }

      context 'when align_denotations returns proper text' do
        before do
          project.stub(:align_denotations).and_return(annotations[:denotations])
        end

        it 'should call align_denotations' do
          expect( project ).to receive(:align_denotations).with(annotations[:denotations], annotations[:text], doc.body)
          project.save_annotations(annotations, doc, {}) 
        end
      end

      context 'when align_denotations returns proper text' do
        before do
          project.stub(:align_denotations).and_return('a')
        end

        it 'should raise error' do
          expect{ project.save_annotations(annotations, doc, {}) }.to raise_error 
        end
      end

      context 'when annotations denotations, relations and modifications present' do
        let(:annotations) { {text: 'text', denotations: 'denotations', relations: 'relations', modifications: 'modifications'} }

        it 'should call save_hdenotations' do
          expect( project ).to receive(:save_hdenotations).with(align_denotations, doc)
          project.save_annotations(annotations, doc, {}) 
        end

        it 'should call save_hrelations' do
          expect( project ).to receive(:save_hrelations).with(annotations[:relations], doc)
          project.save_annotations(annotations, doc, {}) 
        end

        it 'should call save_hmodifications' do
          expect( project ).to receive(:save_hmodifications).with(annotations[:modifications], doc)
          project.save_annotations(annotations, doc, {}) 
        end

        it 'should return annotations' do
          expect( project.save_annotations(annotations, doc, {}) ).to eql({text: doc.body, denotations: align_denotations, relations: annotations[:relations], modifications: annotations[:modifications]})
        end
      end
    end
  end

  describe 'create_annotation_zip' do
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:annotations) { double(:annotations) }
    let(:doc) { FactoryGirl.create(:doc) }
    let(:zip_output_stream) { double(:zip) }
    let(:title) { double(:title) }

    before do
      Dir.stub(:exist?).and_return(true)
      Project.any_instance.stub(:annotations_collection).and_return([annotations])
      project.stub_chain(:get_doc_info, :sub, :gsub).and_return(title)
      project.stub(:annotations).and_return(annotations)
      title.stub(:end_with?).and_return(true)
    end

    it 'should call get_doc_info' do
      expect( project ).to receive(:get_doc_info)
      project.create_annotations_zip(nil)
    end

    it 'should call get_doc_info' do
      expect( annotations ).to receive(:to_json)
      project.create_annotations_zip(nil)
    end

    it 'should call put_next_entry and print' do
      expect_any_instance_of( Zip::OutputStream ).to receive(:put_next_entry)
      expect_any_instance_of( Zip::OutputStream ).to receive(:print)
      project.create_annotations_zip(nil)
    end
  end
end
