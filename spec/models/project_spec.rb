# encoding: utf-8
require 'spec_helper'

describe Project do
  describe 'belongs_to user' do
    before do
      @user = FactoryGirl.create(:user, :id => 5)
      @project = FactoryGirl.create(:project, :user => @user)
    end
    
    it 'project should belongs_to user' do
      @project.user.should eql(@user)
    end
  end
  
  describe 'has_and_belongs_to_many docs' do
    before do
      @doc_1 = FactoryGirl.create(:doc)
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc).id)
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
  
  describe 'has_and_belongs_to_many associate_projects' do
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
  
  describe 'has_many denotations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
    end
    
    it 'project.denotations should be present' do
      @project.denotations.should be_present
    end
    
    it 'project.denotations should include related denotation' do
      (@project.denotations - [@denotation]).should be_blank
    end
  end
  
  describe 'has_many relations' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :project => @project, :obj_id => 5)
    end
    
    it 'project.relations should be present' do
      @project.relations.should be_present
    end
    
    it 'project.relations should include related relation' do
      (@project.relations - [@relation]).should be_blank
    end
  end
  
  describe 'has_many modifications' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @modification = FactoryGirl.create(:modification, :obj => @denotation, :project => @project)
      # @modification = FactoryGirl.create(:modification, :obj_id => 1, :project => @project)      
    end
    
    it 'project.modifications should be present' do
      @project.modifications.should be_present
    end
    
    it 'project.modifications should include related modification' do
      (@project.modifications - [@modification]).should be_blank
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
      @project.destroy
      AssociateMaintainer.all.should be_blank
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
  
  describe 'scope not_id_in' do
    before do
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

  describe 'sort_by_params' do
    context 'when sort by id' do
      before do
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
      before do
        @project_1 = FactoryGirl.create(:project, name: 'A project spec',  user: FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, name: 'B project spec', user: FactoryGirl.create(:user))
        @project_3 = FactoryGirl.create(:project, name: 'a project spec', user: FactoryGirl.create(:user))
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
      before do
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
      before do
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
      before do
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
  
    context 'order_relations_count' do
      before do
        @project_2_relations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :relations_count => 2, :accessibility => 1)
        @project_1_relations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :relations_count => 1, :accessibility => 1)
        @project_0_relations = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :relations_count => 0, :accessibility => 1)
        @projects = Project.order_by(Project, 'relations_count', nil)
      end
      
      it 'project which has 2 relation should be @projects[0]' do
        @projects[0].should eql(@project_2_relations)
      end
      
      it 'project which has 1 relation should be @projects[1]' do
        @projects[1].should eql(@project_1_relations)
      end
      
      it 'project which has 0 relation should be @projects[2]' do
        @projects[2].should eql(@project_0_relations)
      end
    end
  
    context 'not match' do
      before do
        @project_name_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => '00001', :accessibility => 1)
        @project_name_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => '00002', :accessibility => 1)
      end
      
      it 'order by else should return accessible and orde by name ASC' do
        Project.order_by(Project, nil, nil).first.should eql(@project_name_1)
      end
    end 
  end 
  
  describe 'increment_docs_counter' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 2
      @i = 1
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s)
        @i += 1  
      end
      @associate_project_2_pmcdocs_count = 4
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i.to_s) 
        @i += 1  
      end
      @associate_project_2.reload
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
      @pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      @pmcdoc_serial_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1)
      @project.reload
    end
    
    describe 'before add ' do
      it 'project.pmdocs should equal sum of associate projects pmdocs_count and sum of copied pmdocs' do
         @project.pmdocs_count.should eql(@associate_project_2_pmdocs_count * 2)
      end
      
      it 'projectpmcdocs should equal sum of associate projects pmcdocs_count and sum of copied pmcdocs' do
         @project.pmcdocs_count.should eql(@associate_project_2_pmcdocs_count * 2)
      end
    end

    context 'when added PubMed' do
      before do
        @associate_project_1.reload
        @associate_project_1.docs << @pmdoc
        @project.reload
      end
          
      it 'should increment project.pmcdocs_count' do
        @project.pmdocs_count.should eql((@associate_project_2_pmdocs_count * 2) + 1)
        @project.pmcdocs_count.should eql(@associate_project_2_pmcdocs_count * 2)
      end
    end
    
    context 'when added PMC' do
      context 'when serial == 0' do
        before do
          @associate_project_1.reload
          @associate_project_1.docs << @pmcdoc
        end
            
        it 'should increment pmcdocs_count' do
          @project.reload
          @project.pmcdocs_count.should eql((@associate_project_2_pmcdocs_count * 2) + 1)
          @project.pmdocs_count.should eql(@associate_project_2_pmdocs_count * 2)
        end
      end

      context 'when serial == 0' do
        before do
          @associate_project_1.reload
          @associate_project_1.docs << @pmcdoc_serial_1
        end
            
        it 'should not increment pmcdocs_count' do
          @project.reload
          @project.pmcdocs_count.should eql(@associate_project_2_pmcdocs_count * 2)
          @project.pmdocs_count.should eql(@associate_project_2_pmdocs_count * 2)
        end
      end
    end
  end
  
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
  
  describe 'destroyable_for?' do
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
        @project.destroyable_for?(@project_user).should be_true
      end
    end
    
    context 'when current_user is project.associate_maintainer.user' do
      it 'should return false' do
        @project.destroyable_for?(@associate_maintainer_user_1).should be_false
      end
    end
    
    context 'when current_user is project.associate_maintainer.user' do
      it 'should return false' do
        @project.destroyable_for?(@associate_maintainer_user_2).should be_false
      end
    end
    
    context 'when current_user is not project.user nor project.associate_maintainer.user' do
      it 'should return false' do
        @project.destroyable_for?(FactoryGirl.create(:user)).should be_false
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
  
  describe 'build_associate_maintainers' do
    context 'when usernames present' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @user_1 = FactoryGirl.create(:user, :username => 'Username 1')
        @user_2 = FactoryGirl.create(:user, :username => 'Username 2')
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
        @user_1 = FactoryGirl.create(:user, :username => 'Username 1')
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

  describe 'decrement_docs_counter' do
    before do
      @project_pmdocs_count = 1
      @project_pmcdocs_count = 2
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => @project_pmdocs_count, :pmcdocs_count => @project_pmcdocs_count)
      @associate_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1_pmdocs_count = 1
      @i = 1
      @associate_project_1_pmdocs_count.times do
        @associate_project_1.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s) 
        @i += 1 
      end
      @associate_project_1_pmcdocs_count = 1
      @associate_project_1_pmcdocs_count.times do
        @associate_project_1.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i.to_s) 
        @i += 1 
      end     
      @associate_project_1.reload
       
      @associate_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 2
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s) 
        @i += 1 
      end
      @associate_project_2_pmcdocs_count = 3
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i.to_s) 
        @i += 1 
      end     
      @associate_project_2.reload
      
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
      @pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      @pmcdoc_serial_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1)
      @project.reload
      @associate_project_1.reload
      @associate_project_2.reload
    end
    
    describe 'before delete' do
      it 'project.pmdocs should equal sum of associate projects pmdocs_count' do
         @project.pmdocs_count.should eql(@project_pmdocs_count + (@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2)
      end
      
      it 'projectpmcdocs should equal sum of associate projects pmcdocs_count' do
         @project.pmcdocs_count.should eql(@project_pmcdocs_count + (@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
      end
    end

    context 'when deleted PubMed' do
      before do
        @associate_project_1.docs.delete(@pmdoc)
        @project.reload
      end
          
      it 'should decrement project.pmcdocs_count' do
        @project.pmdocs_count.should eql((@project_pmdocs_count + (@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2) - 1)
        @project.pmcdocs_count.should eql(@project_pmcdocs_count + (@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
      end
    end
    
    context 'when deleted PMC' do
      context 'when serial == 0' do
        before do
          @associate_project_1.docs.delete(@pmcdoc)
        end
            
        it 'should decrement pmcdocs_count' do
          @project.reload
          @project.pmcdocs_count.should eql((@project_pmcdocs_count + (@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2) - 1)
          @project.pmdocs_count.should eql(@project_pmdocs_count + (@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2)
        end
      end

      context 'when serial == 1' do
        before do
          @associate_project_1.docs.delete(@pmcdoc_serial_1)
        end
            
        it 'should not decrement pmcdocs_count' do
          @project.reload
          @project.pmcdocs_count.should eql(@project_pmcdocs_count + (@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2)
          @project.pmdocs_count.should eql(@project_pmdocs_count + (@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2)
        end
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
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end
    
    context 'when associate project has relation models' do
      before do
        @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @associate_project_pmdocs_count = 1
        @associate_project_pmdocs_count.times do
          @associate_project.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed') 
        end
        @associate_project_pmcdocs_count = 2
        @associate_project_pmcdocs_count.times do |time|
          @associate_project.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, sourceid: time.to_s) 
        end  
        @associate_project_relations_count = 3
        @associate_project_relations_count.times do
          FactoryGirl.create(:relation, :subj_id => 1, :obj_id => 2, :project_id => @associate_project.id)
        end
        @associate_project_denotations_count = 4
        @associate_project_denotations_count.times do
          FactoryGirl.create(:denotation, :doc_id => 1, :project_id => @associate_project.id)
        end
        @associate_project.reload
        @project.increment_counters(@associate_project)
        @project.reload
      end
      
      it 'should increment pmdocs count' do
        @project.pmdocs_count.should eql(@associate_project_pmdocs_count)
      end
      
      it 'should increment pmcdocs count' do
        @project.pmcdocs_count.should eql(@associate_project_pmcdocs_count)
      end
      
      it 'should increment relations count' do
        @project.relations_count.should eql(@associate_project_relations_count)
      end
      
      it 'should increment denotations count' do
        @project.denotations_count.should eql(@associate_project_denotations_count)
      end
    end
    
    context 'when associate project has relation models' do
      before do
        @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 10, :pmcdocs_count => 20, :relations_count => 30, :denotations_count => 40)
        @project.increment_counters(@associate_project)
        @project.reload
      end
      
      it 'should not increment pmdocs count' do
        @project.pmdocs_count.should eql(0)
      end
      
      it 'should not increment pmcdocs count' do
        @project.pmcdocs_count.should eql(0)
      end
      
      it 'should  not increment relations count' do
        @project.relations_count.should eql(0)
      end
      
      it 'should not increment denotations count' do
        @project.denotations_count.should eql(0)
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
  
  describe 'increment_pending_associate_projects_count' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @associate_projects_count = 2
      @project.stub(:copy_associate_project_relational_models).and_return(nil)
      @associate_projects_count.times do
        @project.associate_projects << FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      end
      @project.reload
    end
    
    it 'should increment project.pending_associate_projects_count' do
      @project.pending_associate_projects_count.should eql(@associate_projects_count)
    end
  end
  
  describe 'copy_associate_project_relational_models' do
    describe 'decrement pending_associate_projects_count' do
      before do
        @associate_projects_count = 2
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pending_associate_projects_count => @associate_projects_count)
        @project.stub(:increment_pending_associate_projects_count).and_return(nil)
        @associate_projects_count.times do
          @project.associate_projects << FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        end
        @project.reload
      end
      
      it 'should increment project.pending_associate_projects_count' do
        @project.pending_associate_projects_count.should eql(0)
      end
    end
    
    describe 'copy docs' do
      before do
        @associate_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        # duplicative docs
        @same_doc_1 = FactoryGirl.create(:doc, :body => 'doc 1', :source => 'http://source', :sourcedb => 'PubMed', :sourceid => '123456', :serial => 1, :section => 'section')
        @same_doc_2 = FactoryGirl.create(:doc, :body => 'doc 2', :source => 'http://source', :sourcedb => 'PMC', :sourceid => '123456', :serial => 0, :section => 'section')
        @associate_project.docs << @same_doc_1
        @associate_project.docs << @same_doc_2
        # not duplicative docs
        @not_same_doc_1 = FactoryGirl.create(:doc, :body => 'doc 1', :source => 'http://source.another', :sourcedb => 'PubMed', :sourceid => '1234567', :serial => 1, :section => 'section')
        @not_same_doc_2 = FactoryGirl.create(:doc, :body => 'doc 2', :source => 'http://source.another', :sourcedb => 'PMC', :sourceid => '1234567', :serial => 0, :section => 'section')
        @associate_project.docs << @not_same_doc_1
        @associate_project.docs << @not_same_doc_2
        @associate_project.reload
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :pmdocs_count => 10, :pmcdocs_count => 20, :denotations_count => 30)
        # add dupulicative docs to project
        @project.docs << @same_doc_1
        @project.docs << @same_doc_2
        @project.reload
      end
      
      describe 'before' do
        it 'project.pmdocs_count should not incremented' do
          @project.pmdocs.to_a.should =~ [@same_doc_1]
        end
        
        it 'project.pmcdocs_count should not incremented' do
          @project.pmcdocs.to_a.should =~ [@same_doc_2]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end

        it 'should include not duplicative pmdoc' do
          @project.pmdocs.to_a.should =~ [@same_doc_1, @not_same_doc_1]
        end
        
        it 'should include not duplicative pmcdoc' do
          @project.pmcdocs.to_a.should =~ [@same_doc_2, @not_same_doc_2]
        end
        
        it 'project.docs should incremented by not duplicative docs count' do
          @project.docs.count.should eql(4)
        end
        
        it 'project.pmdocs_count should incremented by not duplicative pmdocs count' do
          @project.pmdocs_count.should eql(12)
        end
        
        it 'project.pmcdocs_count should incremented by not duplicative pmcdocs count' do
          @project.pmcdocs_count.should eql(22)
        end
      end
    end
    
    describe 'copy denotations' do
      before do
        @doc = FactoryGirl.create(:doc)
        # associate project
        @associate_project =  FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        # associate project same denotation
        @same_denotation_associate = FactoryGirl.create(:denotation,
          :project => @associate_project,
          :doc => @doc
        )
        # associate project not same denotation
        @not_same_denotation_associate = FactoryGirl.create(:denotation,
          :project => @associate_project,
          :begin => @same_denotation_associate.begin + 1,
          :doc => @doc
        )
        # not associate project
        @not_associate_project =  FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        FactoryGirl.create(:denotation,
          :project => @not_associate_project,
          :doc => @doc
        )
        # import project
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @same_denotation_project = FactoryGirl.create(:denotation,
          :project => @project,
          :doc => @doc
        )
      end
      
      describe 'before' do
        it 'project should only have self denotations' do
          @project.denotations.to_a.should =~ [@same_denotation_project]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end
        
        it 'project should import not duplicative denotations' do
          @project.denotations.to_a.should =~ [@same_denotation_project, 
            @project.denotations.where({
              :hid => @not_same_denotation_associate.hid,
              :begin => @not_same_denotation_associate.begin,
              :end => @not_same_denotation_associate.end,
              :obj => @not_same_denotation_associate.obj,
              :doc_id => @not_same_denotation_associate.doc_id,
              :project_id => @project.id
            }).first
           ]
        end      
      end
    end
    
    describe 'copy relations' do
      before do
        @denotation = FactoryGirl.create(:denotation)
        # associate project
        @associate_project =  FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        # associate project same relation
        @same_relation_associate = FactoryGirl.create(:relation,
          :project => @associate_project,
          :obj => @denotation
        )
        # associate project not same denotation
        @not_same_relation_associate = FactoryGirl.create(:relation,
          :project => @associate_project,
          :subj_id => @same_relation_associate.subj_id + 1,
          :obj => @denotation
        )
        # not associate project
        @not_associate_project =  FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        FactoryGirl.create(:relation,
          :project => @not_associate_project,
          :obj => @denotation
        )
        # import project
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @same_relation_project = FactoryGirl.create(:relation,
          :project => @project,
          :obj => @denotation
        )
      end
      
      describe 'before' do
        it 'project should only have self relations' do
          @project.relations.to_a.should =~ [@same_relation_project]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end
        
        it 'project should import not duplicative denotations' do
          @project.relations.to_a.should =~ [@same_relation_project, 
            @project.relations.where({
              :hid => @not_same_relation_associate.hid,
              :subj_id => @not_same_relation_associate.subj_id,
              :subj_type => @not_same_relation_associate.subj_type,
              :obj_id => @not_same_relation_associate.obj_id,
              :obj_type => @not_same_relation_associate.obj_type,
              :pred => @not_same_relation_associate.pred,
              :project_id => @project.id
            }).first
           ]
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
  
  describe 'anncollection' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @get_annotations_for_json = 'get annotations'
      @project.stub(:get_annotations_for_json).and_return(@get_annotations_for_json)
    end
    
    context 'when project.docs present' do
      before do
        @project.docs << FactoryGirl.create(:doc)
      end
      
      it 'should return anncollection' do
        @project.anncollection(nil).should eql([@get_annotations_for_json])
      end
    end
    
    context 'when project.docs blank' do
      it 'should return anncollection' do
        @project.anncollection(nil).should be_blank
      end
    end
  end

  describe 'json' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), namespaces: [{'prefix' => '_base', 'uri' => 'http://base.uri'}, { 'prefix' => 'foaf', 'uri' => 'http://foaf.uri' }])
      @maintainer = 'maintainer'
      @project.stub(:maintainer).and_return(@maintainer)
    end

    it 'should return @project as json except specific columns and include maintainer' do
      @project.json.should eql("{\"accessibility\":null,\"annotations_updated_at\":\"#{@project.annotations_updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"annotations_zip_downloadable\":#{@project.annotations_zip_downloadable},\"author\":null,\"bionlpwriter\":null,\"created_at\":\"#{@project.created_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"denotations_count\":#{@project.denotations_count},\"description\":null,\"editor\":null,\"id\":#{@project.id},\"license\":null,\"name\":\"#{@project.name}\",\"namespaces\":#{@project.namespaces.to_json},\"process\":null,\"rdfwriter\":null,\"reference\":null,\"relations_count\":#{@project.relations_count},\"status\":null,\"updated_at\":\"#{@project.updated_at.strftime("%Y-%m-%dT%H:%M:%SZ")}\",\"viewer\":null,\"xmlwriter\":null,\"maintainer\":\"#{@maintainer}\"}")
    end
  end

  describe 'docs_json_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end

    context 'when docs present' do
      before do
        @doc = FactoryGirl.create(:doc)
        @project.stub(:docs).and_return([@doc])
        @to_hash = 'json'
        @doc.stub(:to_hash).and_return(@to_hash)
      end

      it 'should return collect of docs_hash of projecs.docs' do
        @project.docs_json_hash.should eql([@to_hash])
      end
    end

    context 'when docs blank' do
      before do
        @project.stub(:docs).and_return(nil)
      end

      it 'should return nil' do
        @project.docs_json_hash.should be_nil
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

  describe 'annotations_zip_file_name' do
    it 'should return zip filename' do
      project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      expect(project.annotations_zip_file_name).should eql("#{project.name}-annotations.zip")
    end
  end
  
  describe 'annotations_zip_path' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @annotations_zip_file_name = 'annotations.zip'
      @project.stub(:annotations_zip_file_name).and_return(@annotations_zip_file_name)
    end
    
    it 'should return project annotations zip path' do
      @project.annotations_zip_path.should eql("#{Denotation::ZIP_FILE_PATH}#{@annotations_zip_file_name}")
    end
  end
  
  describe 'save_annotation_zip' do
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

      context 'when public/annotations directory does not exist' do
        before do
          Dir.stub(:exist?).and_return(false)
          FactoryGirl.create(:project, :user => FactoryGirl.create(:user)).save_annotation_zip
        end

        it 'should call mkdir_p with Denotation::ZIP_FILE_PATH' do
          @path.should eql(Denotation::ZIP_FILE_PATH)
        end

        it 'should create @project.notices' do
          expect{ @project.save_annotation_zip }.to change{ @project.notices.count }.from(0).to(1)
        end
      end

      context 'when public/annotations directory exist' do
        before do
          Dir.stub(:exist?).and_return(true)
          FactoryGirl.create(:project, :user => FactoryGirl.create(:user)).save_annotation_zip
        end

        it 'should not call mkdir_p' do
          @path.should be_nil
        end
      end
    end
    
    context 'when project.anncollection blank' do
      before do
         @result = @project.save_annotation_zip
      end
          
      it 'should not create ZIP file' do
        File.exist?("#{Denotation::ZIP_FILE_PATH}#{@name}.zip").should be_false
      end
    end
    
    context 'when project.anncollection present' do
      before do
        Project.any_instance.stub(:anncollection).and_return(
          [{
            :source_db => 'source_db',
            :source_id => 'source_id',
            :division_id => 1,
            :section => 'section',
         }])
         @result = @project.save_annotation_zip
      end
          
      it 'should create ZIP file' do
        File.exist?("#{Denotation::ZIP_FILE_PATH}#{@name}-annotations.zip").should be_true
      end
      
      after do
        File.unlink("#{Denotation::ZIP_FILE_PATH}#{@name}-annotations.zip")
      end
    end

    context 'when error occurred' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project.stub(:anncollection).and_raise('error')
      end

      it 'should create @project.notices' do
        expect{ @project.save_annotation_zip }.to change{ @project.notices.count }.from(0).to(1)
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
    before do
      @zip_file = "#{Denotation::ZIP_FILE_PATH}project.zip"
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

  describe 'save_annotations' do
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
      Shared.stub(:save_annotations).and_return(nil)
    end

    it '' do
      Shared.should_receive(:save_annotations).with({denotations: @denotations, relations: @relations, text: @text}, @project, @doc)
      Project.save_annotations(@project, @doc_annotations_files)
    end
  end

  describe 'add_docs_from_json' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user)) 
    end
    
    context 'when source_dbs prensent' do
      before do
        @attributes = Array.new
        @docs_array = Array.new
        @project.stub(:add_docs) do |options|  
          @attributes << {source_db: options[:sourcedb], ids: options[:ids]}
          @docs_array << options[:docs_array]
          @options_user = options[:user]
          [1, 1, 1]
        end
        @pmc_user_1 = {:source_db => "PMC:user name", :source_id => '1', :div_id => 0, :text => 'body text'}
        @pmc_user_2 = {:source_db => "PMC:user name", :source_id => '1', :div_id => 1, :text => 'body text'} 
        @pmc_1 = {:source_id => "1", :source_db => "PMC"} 
        @pmc_2 = {:source_id => "2", :source_db => "PMC"} 
        @pub_med = {:source_id => "1", :source_db => "PubMed"}
        @user = FactoryGirl.create(:user)
      end

      context 'when json is Array' do
        before do
          docs = [@pmc_user_1, @pmc_user_2, @pmc_1, @pmc_2, @pub_med]
          @result = @project.add_docs_from_json(docs, @user)
        end

        it 'should pass ids and source_db for add_docs correctly' do
          @attributes.should =~ [{source_db: "PMC:user name", ids: "1,1"}, {source_db: "PMC", ids: "1,2"}, {source_db: "PubMed", ids: "1"}]
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

        it 'should pass ids and source_db for add_docs correctly' do
          @attributes.should =~ [{source_db: "PMC:user name", ids: "1"}]
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
  
  describe 'add_docs' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @sourceid = '8424'
      @sourcedb = 'PMC'
      @user = FactoryGirl.create(:user, username: 'Add Docs User Name')
    end 
    
    context 'when divs present' do
      context 'when sourcedb is current_users sourcedb' do
        before do
          @user_soucedb = "PMC#{Doc::UserSourcedbSeparator}#{@user.username}"
          @doc_1 = FactoryGirl.create(:doc, :sourcedb => @user_soucedb, :sourceid => @sourceid, :serial => 0)
          @doc_2 = FactoryGirl.create(:doc, :sourcedb => @user_soucedb, :sourceid => @sourceid, :serial => 1)
          @docs_array = [
            # successfully update
            {'id' => 1, 'text' => 'doc body1', 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 0},
            {'id' => 2, 'text' => 'doc body2', 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1},
            # successfully create
            {'id' => 3, 'text' => 'doc body3', 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 2},
            # successfully update save serial(div_id) record
            {'text' => 'doc body4', 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1},
            # fail create
            {'id' => 4, 'text' => nil, 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 3},
            # fail update
            {'text' => nil, 'source_db' => @user_soucedb, 'source_id' => @sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 0}
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
            @doc_1.body == @docs_array[0]['text'] && @doc_1.sourcedb == @docs_array[0]['source_db'] && @doc_1.source == @docs_array[0]['source_url'] && @doc_1.serial == @docs_array[0]['div_id']
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[0]['text'] && doc.sourcedb == @docs_array[0]['source_db'] && doc.source == @docs_array[0]['source_url'] && doc.serial == @docs_array[0]['div_id']}.should be_present
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[2]['text'] && doc.sourcedb == @docs_array[2]['source_db'] && doc.source == @docs_array[2]['source_url'] && doc.serial == @docs_array[2]['div_id']}.should be_present
          end

          it 'should update exists doc' do
            @doc_2.body == @docs_array[3]['text'] && @doc_1.sourcedb == @docs_array[3]['source_db'] && @doc_1.source == @docs_array[3]['source_url'] && @doc_1.serial == @docs_array[3]['div_id']
          end

          it 'should add project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[3]['text'] && doc.sourcedb == @docs_array[3]['source_db'] && doc.source == @docs_array[3]['source_url'] && doc.serial == @docs_array[3]['div_id']}.should be_present
          end

          it 'should add and update project.docs' do
            @project.docs.select{|doc| doc.body == @docs_array[0]['text'] && doc.sourcedb == @docs_array[0]['source_db'] && doc.source == @docs_array[0]['source_url'] && doc.serial == @docs_array[0]['div_id']}.should be_present
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
          
          before do
            @result = @project.add_docs({ids: @sourceid, sourcedb: @sourcedb, docs_array: nil, user: @user})
            @project.reload
          end

          it '@project should include @doc' do
            @project.docs.should include(@doc)
          end
          
          it 'should not increment num_added' do
            @result.should eql [0, 0, 0]
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
                {'id' => 1, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => '123', 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'div_id' => 0},
                {'id' => 2, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => '123', 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1},
                # fail since same sourcedb, sourceid and serial
                {'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => '123', 'source_url' => 'http://user.sourcedb/', 'div_id' => 1}
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
                {'id' => 1, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => 123, 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'div_id' => 0},
                {'id' => 2, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => 123, 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1},
                {'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => 123, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1}
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
              @result = @project.add_docs({ ids: @sourceid, sourcedb: @sourcedb, docs_array: nil, user: @user})
            end
            
            it 'should increment num_created' do
              @result.should eql [Doc.find_all_by_sourcedb_and_sourceid(@sourcedb, @new_sourceid).size, 0, 0]
            end
          end

          context 'when doc_sequencer_ blank' do
            before do
              @new_sourceid = '123456'
              @docs_array = [
                # successfully create
                {'id' => 1, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => @new_sourceid, 'serial' => 0, 'source_url' => 'http://user.sourcedb/', 'div_id' => 0},
                {'id' => 2, 'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => @new_sourceid, 'serial' => 1, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1},
                # fail since same sourcedb, sourceid and serial
                {'text' => 'doc body', 'source_db' => @sourcedb, 'source_id' => @new_sourceid, 'source_url' => 'http://user.sourcedb/', 'div_id' => 1}
              ]
              Doc.stub(:create_divs).and_return([@generated_doc_1, @generated_doc_2])
              @sourcedb = 'source_db'
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
        
        it 'should not increment num_failed' do
          @result.should eql [0, 0, 1]
        end
      end            
    end
  end

  describe 'update_annotations_updated_at' do
    before do
      @doc = FactoryGirl.create(:doc)
      @annotations_updated_at = 5.days.ago
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), annotations_updated_at: @annotations_updated_at )
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), annotations_updated_at: @annotations_updated_at )
    end

    describe 'after_add' do
      before do
        @project_1.docs << @doc
        @project_2.docs << @doc
      end

      it 'should update projects.annotations_updated_at' do
        @project_1.annotations_updated_at.should_not eql(@annotations_updated_at)
        @project_2.annotations_updated_at.should_not eql(@annotations_updated_at)
      end
    end

    describe 'after_remove' do
      before do
        @project_1.docs.delete(@doc)
        @project_2.docs.delete(@doc)
      end

      it 'should update projects.annotations_updated_at' do
        @project_1.annotations_updated_at.should_not eql(@annotations_updated_at)
        @project_2.annotations_updated_at.should_not eql(@annotations_updated_at)
      end
    end
  end

  describe 'create_user_sourcedb_docs' do
    before do
      @project = FactoryGirl.build(:project, user: FactoryGirl.create(:user))  
      @docs_array = [
        {text: 'text', source_db: 'sdb', source_id: 'sid', section: 'section', source_url: 'http', div_id: 0},
        {text: 'text', source_db: 'sdb', source_id: nil, section: 'section', source_url: 'http', div_id: 0}
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
          {text: 'text', source_db: 'sdb', source_id: 'sid', section: 'section', source_url: 'http', div_id: 0}
        ]  
        sourcedb = 'param sdb'
        nil.stub(:valid?).and_return(true)
        nil.stub(:save).and_return(true)
        expect(Doc).to receive(:new).with({body: docs_array[0][:text], sourcedb: sourcedb, sourceid: docs_array[0][:source_id], section: docs_array[0][:section], source: docs_array[0][:source_url], serial: docs_array[0][:div_id]})
        @project.create_user_sourcedb_docs({docs_array: docs_array, sourcedb: sourcedb})
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
end
