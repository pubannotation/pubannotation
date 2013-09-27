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
  
  describe 'scope sprojects_projects' do
    before do
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
    end
    
    it 'should include project_id included in project_ids' do
      Project.sprojects_projects([@project_1.id, @project_2.id]).should =~ [@project_1, @project_2]
    end    
  end
  
  describe 'scope not_sprojects_projects' do
    before do
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @project_3 = FactoryGirl.create(:project)
    end
    
    it 'should include project_id included in project_ids' do
      Project.not_sprojects_projects([@project_1.id, @project_2.id]).should =~ [@project_3]
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
      @sproject_1 = FactoryGirl.create(:sproject, :pmdocs_count => 0, :pmcdocs_count => 0)
      FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject_1.id)
      @sproject_2 = FactoryGirl.create(:sproject, :pmdocs_count => 1, :pmcdocs_count => 1)
      FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject_2.id)
      @pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
      @pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC')
    end
    
    context 'when PubMed' do
      before do
        @project.docs << @pmdoc
      end
          
      it 'should increment project.pmcdocs_count' do
        @project.reload
        @project.pmdocs_count.should eql(1)
        @project.pmcdocs_count.should eql(0)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_1.reload
        @sproject_1.pmdocs_count.should eql(1)
        @sproject_1.pmcdocs_count.should eql(0)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_2.reload
        @sproject_2.pmdocs_count.should eql(2)
        @sproject_2.pmcdocs_count.should eql(1)
      end
    end
    
    context 'when PMC' do
      before do
        @project.docs << @pmcdoc
      end
          
      it 'should increment pmcdocs_count' do
        @project.reload
        @project.pmcdocs_count.should eql(1)
        @project.pmdocs_count.should eql(0)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_1.reload
        @sproject_1.pmcdocs_count.should eql(1)
        @sproject_1.pmdocs_count.should eql(0)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_2.reload
        @sproject_2.pmcdocs_count.should eql(2)
        @sproject_2.pmdocs_count.should eql(1)
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
   
  describe 'associate_maintaines_addable_for?' do
    before do
      @project_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @project_user)
      @associate_maintainer_user = FactoryGirl.create(:user)
      FactoryGirl.create(:associate_maintainer, :project => @project, :user => @associate_maintainer_user)
    end
    
    context 'when current_user is project.user' do
      it 'should return true' do
        @project.associate_maintaines_addable_for?(@project_user).should be_true
      end
    end
    
    context 'when current_user is not project.user' do
      it 'should return false' do
        @project.associate_maintaines_addable_for?(@associate_maintainer_user).should be_false
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
      
      it 'should ass associate @project.maintainers' do
       associate_maintainer_users = @project.associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
       associate_maintainer_users.should =~ [@user_1, @user_2]
      end
    end
  end

  describe 'decrement_docs_counter' do
    before do
      @project = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 1)
      @sproject_1 = FactoryGirl.create(:sproject, :pmdocs_count => 1, :pmcdocs_count => 1)
      FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject_1.id)
      @sproject_2 = FactoryGirl.create(:sproject, :pmdocs_count => 2, :pmcdocs_count => 2)
      FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject_2.id)
      @pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
      @pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC')
    end
  
    context 'when PubMed' do
      before do
        @project.docs.delete(@pmdoc)
      end
          
      it 'should increment project.pmcdocs_count' do
        @project.reload
        @project.pmdocs_count.should eql(0)
        @project.pmcdocs_count.should eql(1)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_1.reload
        @sproject_1.pmdocs_count.should eql(0)
        @sproject_1.pmcdocs_count.should eql(1)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_2.reload
        @sproject_2.pmdocs_count.should eql(1)
        @sproject_2.pmcdocs_count.should eql(2)
      end
    end
  
    context 'when PMC' do
      before do
        @project.docs.delete(@pmcdoc)
      end
          
      it 'should increment pmcdocs_count' do
        @project.reload
        @project.pmcdocs_count.should eql(0)
        @project.pmdocs_count.should eql(1)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_1.reload
        @sproject_1.pmcdocs_count.should eql(0)
        @sproject_1.pmdocs_count.should eql(1)
      end

      it 'should increment sproject.pmcdocs_count' do
        @sproject_2.reload
        @sproject_2.pmcdocs_count.should eql(1)
        @sproject_2.pmdocs_count.should eql(2)
      end
    end
  end
end
