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
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
      @associate_project_1 = FactoryGirl.create(:project)
      @associate_project_2 = FactoryGirl.create(:project)
      @associate_project_3 = FactoryGirl.create(:project)

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
  
  describe 'has_many instances' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @instance = FactoryGirl.create(:instance, :obj_id => 10, :project => @project)
    end
    
    it 'project.instances should present' do
      @project.instances.should be_present
    end
    
    it 'project.instances should include related instance' do
      (@project.instances - [@instance]).should be_blank
    end
  end
  
  describe 'has_many modifications' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @modification = FactoryGirl.create(:modification, :obj_id => 1, :project => @project)      
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
      @project.associate_maintainers.should =~ [@associate_maintainer_1, @associate_maintainer_2]
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
      @project.associate_maintainer_users.should =~ [@user_1, @user_2]
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
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
    end
    
    it 'should include project_id included in project_ids' do
      Project.not_id_in([@project_1.id, @project_2.id]).should =~ [@project_3]
    end    
  end
  
  describe 'scope id_in' do
    before do
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
    end
    
    it 'should include project_id included in project_ids' do
      Project.id_in([@project_1.id, @project_2.id]).should =~ [@project_1, @project_2]
    end    
  end
  
  describe 'status_text' do
    context 'when status = 1' do
      before do
        @project = FactoryGirl.create(:project, :status => 1)
      end 
      
      it 'should return I18n released' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.released'))
      end
    end
    
    context 'when status = 2' do
      before do
        @project = FactoryGirl.create(:project, :status => 2)
      end 
      
      it 'should return I18n beta' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.beta'))
      end
    end

    context 'when status = 3' do
      before do
        @project = FactoryGirl.create(:project, :status => 3)
      end 
      
      it 'should return I18n developing' do
        @project.status_text.should eql(I18n.t('activerecord.options.project.status.developing'))
      end
    end
  end
  
  describe 'accessibility_text' do
    context 'when accessibility = 1' do
      before do
        @project = FactoryGirl.create(:project, :accessibility => 1)
      end 
      
      it 'should return I18n released' do
        @project.accessibility_text.should eql(I18n.t('activerecord.options.project.accessibility.public'))
      end
    end
    
    context 'when accessibility = 2' do
      before do
        @project = FactoryGirl.create(:project, :accessibility => 2)
      end 
      
      it 'should return I18n beta' do
        @project.accessibility_text.should eql(:Private)
      end
    end
  end
  
  describe 'self.order_by' do
    context 'pmdocs_count' do
      before do
        @project_pmdocs_1 = FactoryGirl.create(:project, :pmdocs_count => 1, :accessibility => 1)
        @project_pmdocs_2 = FactoryGirl.create(:project, :pmdocs_count => 2, :accessibility => 1)
        @project_pmdocs_4 = FactoryGirl.create(:project, :pmdocs_count => 4, :accessibility => 1)
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
        @project_pmcdocs_1 = FactoryGirl.create(:project, :pmcdocs_count => 1, :accessibility => 1)
        @project_pmcdocs_2 = FactoryGirl.create(:project, :pmcdocs_count => 2, :accessibility => 1)
        @project_pmcdocs_4 = FactoryGirl.create(:project, :pmcdocs_count => 4, :accessibility => 1)
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
        @project_2_denotations = FactoryGirl.create(:project, :denotations_count => 2, :accessibility => 1)
        @project_1_denotations = FactoryGirl.create(:project, :denotations_count => 1, :accessibility => 1)
        @project_0_denotations = FactoryGirl.create(:project, :denotations_count => 0, :accessibility => 1)
        @projects = Project.order_by(Project, 'order_denotations_count', nil)
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
        @project_2_relations = FactoryGirl.create(:project, :relations_count => 2, :accessibility => 1)
        @project_1_relations = FactoryGirl.create(:project, :relations_count => 1, :accessibility => 1)
        @project_0_relations = FactoryGirl.create(:project, :relations_count => 0, :accessibility => 1)
        @projects = Project.order_by(Project, 'order_relations_count', nil)
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
        @project_name_1 = FactoryGirl.create(:project, :name => '00001', :accessibility => 1)
        @project_name_2 = FactoryGirl.create(:project, :name => '00002', :accessibility => 1)
      end
      
      it 'order by else should return accessible and orde by name ASC' do
        Project.order_by(Project, nil, nil).first.should eql(@project_name_1)
      end
    end 
  end 
  
  describe 'increment_docs_counter' do
    before do
      @project = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 2
      @i = 1
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i)
        @i += 1  
      end
      @associate_project_2_pmcdocs_count = 4
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
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
  
  describe 'order_author' do
    before do
      @project_1 = FactoryGirl.create(:project, :author => 'A')
      @project_2 = FactoryGirl.create(:project, :author => 'B')
      @project_3 = FactoryGirl.create(:project, :author => 'C')
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
        @project = FactoryGirl.create(:project)
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
        @project = FactoryGirl.create(:project)
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
      @project = FactoryGirl.create(:project)
      @associate_project_have_no_associate_projects = FactoryGirl.create(:project, :accessibility => 1)
      @associated_project = FactoryGirl.create(:project, :accessibility => 1)
      @associate_project_have_associate_projects_1 = FactoryGirl.create(:project, :accessibility => 1)
      @associate_project_have_associate_projects_1.associate_projects << @associated_project
      @associate_project_have_associate_projects_1.reload      
      @associate_project_have_associate_projects_2 = FactoryGirl.create(:project, :accessibility => 1)
      @associate_project_have_associate_projects_2.associate_projects << @associated_project
      @associated_project_unaccessible = FactoryGirl.create(:project, :accessibility => 2, :user => @user)
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
                @project.associate_projects.should =~ [
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
                @project.associate_projects.should =~ [
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
              @project.associate_projects.should =~ [
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
          @project.associate_projects.should =~ [
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
      @project = FactoryGirl.create(:project, :pmdocs_count => @project_pmdocs_count, :pmcdocs_count => @project_pmcdocs_count)
      @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1_pmdocs_count = 1
      @i = 1
      @associate_project_1_pmdocs_count.times do
        @associate_project_1.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i) 
        @i += 1 
      end
      @associate_project_1_pmcdocs_count = 1
      @associate_project_1_pmcdocs_count.times do
        @associate_project_1.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
        @i += 1 
      end     
      @associate_project_1.reload
       
      @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 2
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.pmdocs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i) 
        @i += 1 
      end
      @associate_project_2_pmcdocs_count = 3
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
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
        @project_1 = FactoryGirl.create(:project)
        @project_2 = FactoryGirl.create(:project)
        @project_3 = FactoryGirl.create(:project)
        @project_4 = FactoryGirl.create(:project)
        @associate_project_1 = FactoryGirl.create(:project)
        @associate_project_2 = FactoryGirl.create(:project)
        @associate_project_3 = FactoryGirl.create(:project)
  
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
        @project = FactoryGirl.create(:project)
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
          @project = FactoryGirl.create(:project)
          @associate_project_ids = ['A', 'B']
          @project.stub(:associate_project_and_project_ids).and_return(@associate_project_ids)
        end
        
        it 'should return associate_project_ids and self id' do
          @project.self_id_and_associate_project_and_project_ids.should =~ @associate_project_ids << @project.id
        end
      end

      context 'when associate_project_and_project_ids blank' do
        before do
          @project = FactoryGirl.create(:project)
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
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @associate_project_1 = FactoryGirl.create(:project)
      @associate_project_2 = FactoryGirl.create(:project)
      @associate_project_3 = FactoryGirl.create(:project)

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
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
      @project_4 = FactoryGirl.create(:project)
      @associate_project_1 = FactoryGirl.create(:project)
      @associate_project_2 = FactoryGirl.create(:project)
      @associate_project_3 = FactoryGirl.create(:project)

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
      @accessible_1 = FactoryGirl.create(:project)
      @accessible_2 = FactoryGirl.create(:project)
      @un_accessible = FactoryGirl.create(:project)
      @not_id_in = FactoryGirl.create(:project)
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
        @project = FactoryGirl.create(:project)
      end
      
      it 'should return Project.accessible(current_user).not_id_in()' do
        @project.associatable_project_ids(@current_user).should =~ [@not_id_in.id]
      end
    end
  end
  
  describe 'increment_counters' do
    before do
      @project = FactoryGirl.create(:project)
    end
    
    context 'when associate project has relation models' do
      before do
        @associate_project = FactoryGirl.create(:project)
        @associate_project_pmdocs_count = 1
        @associate_project_pmdocs_count.times do
          @associate_project.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed') 
        end
        @associate_project_pmcdocs_count = 2
        @associate_project_pmcdocs_count.times do
          @associate_project.pmcdocs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0) 
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
        @associate_project = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :relations_count => 30, :denotations_count => 40)
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
      @project = FactoryGirl.create(:project)
      @project_pmdocs_count = 1
      @project_pmdocs_count.times do
        doc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PubMed')
        @project.docs << doc
      end
      @project_pmcdocs_count = 2
      @project_pmcdocs_count.times do
        doc = FactoryGirl.create(:doc, :body => 'doc 2', :sourcedb => 'PMC', :serial => 0)
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
        :pmdocs_count => @associate_pmdocs_count, 
        :pmcdocs_count => @associate_pmcdocs_count, 
        :denotations_count => @associate_denotations_count)
      @dup_pmdocs_count = 2
      @i = 1
      @dup_pmdocs_count.times do
        pmdoc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PubMed', :sourceid => @i)
        @i += 1
        @associate_project.docs << pmdoc
      end

      @dup_pmcdocs_count = 3
      @dup_pmcdocs_count.times do
        pmcdoc = FactoryGirl.create(:doc, :body => 'doc 1', :sourcedb => 'PMC', :serial => 0, :sourceid => @i)
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
      @project = FactoryGirl.create(:project)
      @associate_projects_count = 2
      @project.stub!(:copy_associate_project_relational_models).and_return(nil)
      @associate_projects_count.times do
        @project.associate_projects << FactoryGirl.create(:project)
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
        @project = FactoryGirl.create(:project, :pending_associate_projects_count => @associate_projects_count)
        @project.stub!(:increment_pending_associate_projects_count).and_return(nil)
        @associate_projects_count.times do
          @project.associate_projects << FactoryGirl.create(:project)
        end
        @project.reload
      end
      
      it 'should increment project.pending_associate_projects_count' do
        @project.pending_associate_projects_count.should eql(0)
      end
    end
    
    describe 'copy docs' do
      before do
        @associate_project = FactoryGirl.create(:project)
        # duplicative docs
        @same_doc_1 = FactoryGirl.create(:doc, :body => 'doc 1', :source => 'http://source', :sourcedb => 'PubMed', :sourceid => 123456, :serial => 1, :section => 'section')
        @same_doc_2 = FactoryGirl.create(:doc, :body => 'doc 2', :source => 'http://source', :sourcedb => 'PMC', :sourceid => 123456, :serial => 0, :section => 'section')
        @associate_project.docs << @same_doc_1
        @associate_project.docs << @same_doc_2
        # not duplicative docs
        @not_same_doc_1 = FactoryGirl.create(:doc, :body => 'doc 1', :source => 'http://source.another', :sourcedb => 'PubMed', :sourceid => 123456, :serial => 1, :section => 'section')
        @not_same_doc_2 = FactoryGirl.create(:doc, :body => 'doc 2', :source => 'http://source.another', :sourcedb => 'PMC', :sourceid => 123456, :serial => 0, :section => 'section')
        @associate_project.docs << @not_same_doc_1
        @associate_project.docs << @not_same_doc_2
        @associate_project.reload
        @project = FactoryGirl.create(:project, :pmdocs_count => 10, :pmcdocs_count => 20, :denotations_count => 30)
        # add dupulicative docs to project
        @project.docs << @same_doc_1
        @project.docs << @same_doc_2
        @project.reload
      end
      
      describe 'before' do
        it 'project.pmdocs_count should not incremented' do
          @project.pmdocs.should =~ [@same_doc_1]
        end
        
        it 'project.pmcdocs_count should not incremented' do
          @project.pmcdocs.should =~ [@same_doc_2]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end

        it 'should include not duplicative pmdoc' do
          @project.pmdocs.should =~ [@same_doc_1, @not_same_doc_1]
        end
        
        it 'should include not duplicative pmcdoc' do
          @project.pmcdocs.should =~ [@same_doc_2, @not_same_doc_2]
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
        @associate_project =  FactoryGirl.create(:project)
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
        @not_associate_project =  FactoryGirl.create(:project)
        FactoryGirl.create(:denotation,
          :project => @not_associate_project,
          :doc => @doc
        )
        # import project
        @project = FactoryGirl.create(:project)
        @same_denotation_project = FactoryGirl.create(:denotation,
          :project => @project,
          :doc => @doc
        )
      end
      
      describe 'before' do
        it 'project should only have self denotations' do
          @project.denotations.should =~ [@same_denotation_project]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end
        
        it 'project should import not duplicative denotations' do
          @project.denotations.should =~ [@same_denotation_project, 
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
        @associate_project =  FactoryGirl.create(:project)
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
        @not_associate_project =  FactoryGirl.create(:project)
        FactoryGirl.create(:relation,
          :project => @not_associate_project,
          :obj => @denotation
        )
        # import project
        @project = FactoryGirl.create(:project)
        @same_relation_project = FactoryGirl.create(:relation,
          :project => @project,
          :obj => @denotation
        )
      end
      
      describe 'before' do
        it 'project should only have self relations' do
          @project.relations.should =~ [@same_relation_project]
        end
      end
      
      describe 'after' do
        before do
          @project.copy_associate_project_relational_models(@associate_project)
          @project.reload
        end
        
        it 'project should import not duplicative denotations' do
          @project.relations.should =~ [@same_relation_project, 
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
end
