# encoding: utf-8
require 'spec_helper'

describe Sproject do
  describe 'scope accessible' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      @accessibility_0_user_1 = FactoryGirl.create(:sproject, :accessibility => 0, :user => @user_1)  
      @accessibility_1_user_1 = FactoryGirl.create(:sproject, :accessibility => 1, :user => @user_1)  
      @accessibility_0_user_2 = FactoryGirl.create(:sproject, :accessibility => 0, :user => @user_2)  
      @accessibility_1_user_2 = FactoryGirl.create(:sproject, :accessibility => 1, :user => @user_2)  
    end
    
    context 'when current_user present' do
      before do
        @sprojects = Sproject.accessible(@user_1)
      end
      
      it 'includes accessibility = 1 and user is not current_user' do
        @sprojects.should include(@accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1 and user is current_user' do
        @sprojects.should include(@accessibility_1_user_1)
      end
      
      it 'not includes accessibility != 1 and user is not current_user' do
        @sprojects.should_not include(@accessibility_0_user_2)
      end
      
      it 'includes accessibility != 1 and user is current_user' do
        @sprojects.should include(@accessibility_0_user_1)
      end
    end
    
    context 'when current_user blank' do
      before do
        @sprojects = Sproject.accessible(nil)
      end
      
      it 'includes accessibility = 1' do
        @sprojects.should include(@accessibility_1_user_1)
      end
      
      it 'includes accessibility = 1' do
        @sprojects.should include(@accessibility_1_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @sprojects.should_not include(@accessibility_0_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @sprojects.should_not include(@accessibility_0_user_1)
      end
    end
  end
  
  describe 'scope order_pmdocs_count' do
    before do
      # Project
      @project_1 = FactoryGirl.create(:project)
      3.times do |i|
        FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => i)
      end

      @project_2 = FactoryGirl.create(:project)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc, :sourcedb => 'PubMed'))

      @project_3 = FactoryGirl.create(:project)
      FactoryGirl.create(:docs_project, :project_id => @project_3.id, :doc_id => FactoryGirl.create(:doc, :sourcedb => 'PubMed'))

      @project_4 = FactoryGirl.create(:project)

      # Sproject
      @sproject_1 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject_1.id)

      @sproject_2 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_4.id, :sproject_id => @sproject_2.id)

      @sproject_3 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_2.id, :sproject_id => @sproject_3.id)
      FactoryGirl.create(:projects_sproject, :project_id => @project_3.id, :sproject_id => @sproject_3.id)
      
      @sprojects = Sproject.order_pmdocs_count
    end
    
    it 'should return has most pmdocs first' do
      @sprojects.first.should eql(@sproject_1)
    end
    
    it 'should return has most pmdocs second' do
      @sprojects[1].should eql(@sproject_3)
    end
    
    it 'should return has least pmdocs last' do
      @sprojects.last.should eql(@sproject_2)
    end
  end
  
  describe 'scope order_pmcdocs_count' do
    before do
      # Project
      @project_1 = FactoryGirl.create(:project)
      3.times do |i|
        FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => i)
      end

      @project_2 = FactoryGirl.create(:project)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc, :sourcedb => 'PMC'))

      @project_3 = FactoryGirl.create(:project)
      FactoryGirl.create(:docs_project, :project_id => @project_3.id, :doc_id => FactoryGirl.create(:doc, :sourcedb => 'PMC'))

      @project_4 = FactoryGirl.create(:project)

      # Sproject
      @sproject_1 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject_1.id)

      @sproject_2 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_4.id, :sproject_id => @sproject_2.id)

      @sproject_3 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_2.id, :sproject_id => @sproject_3.id)
      FactoryGirl.create(:projects_sproject, :project_id => @project_3.id, :sproject_id => @sproject_3.id)
      
      @sprojects = Sproject.order_pmcdocs_count
    end
    
    it 'should return has most pmdocs first' do
      @sprojects.first.should eql(@sproject_1)
    end
    
    it 'should return has most pmdocs second' do
      @sprojects[1].should eql(@sproject_3)
    end
    
    it 'should return has least pmdocs last' do
      @sprojects.last.should eql(@sproject_2)
    end
  end
  
  describe 'scope order_denotations_count' do
    before do
      # Project
      @project_1 = FactoryGirl.create(:project)
      3.times do |i|
        FactoryGirl.create(:denotation, :project => @project_1, :doc_id => i)
      end

      @project_2 = FactoryGirl.create(:project)
      FactoryGirl.create(:denotation, :project => @project_2, :doc_id => 4)

      @project_3 = FactoryGirl.create(:project)
      FactoryGirl.create(:denotation, :project => @project_3, :doc_id => 5)

      @project_4 = FactoryGirl.create(:project)

      # Sproject
      @sproject_1 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject_1.id)

      @sproject_2 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_4.id, :sproject_id => @sproject_2.id)

      @sproject_3 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_2.id, :sproject_id => @sproject_3.id)
      FactoryGirl.create(:projects_sproject, :project_id => @project_3.id, :sproject_id => @sproject_3.id)
      
      @sprojects = Sproject.order_denotations_count
    end
    
    it 'should return has most pmdocs first' do
      @sprojects.first.should eql(@sproject_1)
    end
    
    it 'should return has most pmdocs second' do
      @sprojects[1].should eql(@sproject_3)
    end
    
    it 'should return has least pmdocs last' do
      @sprojects.last.should eql(@sproject_2)
    end
  end
  
  describe 'scope order_relations_count' do
    before do
      # Project
      @project_1 = FactoryGirl.create(:project)
      3.times do |i|
        FactoryGirl.create(:relation, :project => @project_1, :obj_id => i)
      end

      @project_2 = FactoryGirl.create(:project)
      FactoryGirl.create(:relation, :project => @project_2, :obj_id => 4)

      @project_3 = FactoryGirl.create(:project)
      FactoryGirl.create(:relation, :project => @project_3, :obj_id => 5)

      @project_4 = FactoryGirl.create(:project)

      # Sproject
      @sproject_1 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject_1.id)

      @sproject_2 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_4.id, :sproject_id => @sproject_2.id)

      @sproject_3 = FactoryGirl.create(:sproject)
      FactoryGirl.create(:projects_sproject, :project_id => @project_2.id, :sproject_id => @sproject_3.id)
      FactoryGirl.create(:projects_sproject, :project_id => @project_3.id, :sproject_id => @sproject_3.id)
      
      @sprojects = Sproject.order_relations_count
    end
    
    it 'should return has most pmdocs first' do
      @sprojects.first.should eql(@sproject_1)
    end
    
    it 'should return has most pmdocs second' do
      @sprojects[1].should eql(@sproject_3)
    end
    
    it 'should return has least pmdocs last' do
      @sprojects.last.should eql(@sproject_2)
    end
  end
  
  describe 'self.order_by' do
    before do
      @sproject_pmdocs_count = FactoryGirl.create(:sproject, :pmdocs_count => 4, :pmcdocs_count => 1, :denotations_count => 1, :relations_count => 1, :accessibility => 1)
      @sproject_pmcdocs_count = FactoryGirl.create(:sproject, :pmdocs_count => 1, :pmcdocs_count => 4, :denotations_count => 2, :relations_count => 2, :accessibility => 1)
      @sproject_denotations_count = FactoryGirl.create(:sproject, :pmdocs_count => 2, :pmcdocs_count => 2, :denotations_count => 4, :relations_count => 3, :accessibility => 1)
      @sproject_relations_count = FactoryGirl.create(:sproject, :pmdocs_count => 3, :pmcdocs_count => 3, :denotations_count => 3, :relations_count => 4, :accessibility => 1)
    end
    
    context 'when pmdocs_count' do
      before do
        @sprojects = Sproject.order_by(Sproject, 'pmdocs_count', nil)
      end
      
      it 'should return order by column' do
        @sprojects.first.should eql(@sproject_pmdocs_count)
      end
    end
    
    context 'when pmcdocs_count' do
      before do
        @sprojects = Sproject.order_by(Sproject, 'pmcdocs_count', nil)
      end
      
      it 'should return order by column' do
        @sprojects.first.should eql(@sproject_pmcdocs_count)
      end
    end
    
    context 'when denotations_count' do
      before do
        @sprojects = Sproject.order_by(Sproject, 'denotations_count', nil)
      end
      
      it 'should return order by column' do
        @sprojects.first.should eql(@sproject_denotations_count)
      end
    end
    
    context 'when relations_count' do
      before do
        @sprojects = Sproject.order_by(Sproject, 'relations_count', nil)
      end
      
      it 'should return order by column' do
        @sprojects.first.should eql(@sproject_relations_count)
      end
    end
  end 
  
  describe 'pmdocs' do
    before do
      @doc = FactoryGirl.create(:doc, )
      Doc.stub(:pmdocs).and_return(@doc)
      Doc.any_instance.stub(:projects_docs).and_return(@doc)
      @sproject = FactoryGirl.create(:sproject)
      @pmdocs = @sproject.pmdocs
    end
    
    it 'should return Doc.pmdocs.project_docs' do
      @pmdocs.should eql(@doc)
    end
  end
  
  describe 'pmcdocs' do
    before do
      @doc = FactoryGirl.create(:doc, )
      Doc.stub(:pmcdocs).and_return(@doc)
      Doc.any_instance.stub(:projects_docs).and_return(@doc)
      @sproject = FactoryGirl.create(:sproject)
      @pmcdocs = @sproject.pmcdocs
    end
    
    it 'should return Doc.pmcdocs.project_docs' do
      @pmcdocs.should eql(@doc)
    end
  end
  
  describe 'project_ids' do
    before do
      @sproject = FactoryGirl.create(:sproject)
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
    end
    
    context 'when projects.present' do
      before do
        FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject.id)
        FactoryGirl.create(:projects_sproject, :project_id => @project_2.id, :sproject_id => @sproject.id)
        @project_ids = @sproject.project_ids 
      end
      
      it 'should return projects ids' do
        @project_ids.should =~ [@project_1.id, @project_2.id]
      end
    end
    
    context 'when projects.blank' do
      before do
        @project_ids = @sproject.project_ids 
      end
      
      it 'should return default ids' do
        @project_ids.should =~ [0]
      end
    end
  end
  
  describe 'accessible?' do
    before do
      @project_user = FactoryGirl.create(:user)
    end

    context 'when accessibility == 1' do
      before do
        @sproject = FactoryGirl.create(:sproject, :accessibility => 1, :user => @project_user)  
      end
      
      context 'when user_signed_in? == true' do
        context 'when user == current_user' do
          before do
            @accessible = @sproject.accessible?(@project_user) 
          end
          
          it 'should return true' do
            @accessible.should be_true
          end
        end
        
        context 'when user != current_user' do
          before do
            @accessible = @sproject.accessible?(FactoryGirl.create(:user)) 
          end
          
          it 'should return true' do
            @accessible.should be_true
          end
        end
      end
    end

    context 'when accessibility != 1' do
      before do
        @sproject = FactoryGirl.create(:sproject, :accessibility => 0, :user => @project_user)  
      end
      
      context 'when user_signed_in? == true' do
        before do
          Sproject.any_instance.stub(:user_signed_in?).and_return(true)  
        end
        
        context 'when user == current_user' do
          before do
            @accessible = @sproject.accessible?(@project_user) 
          end
          
          it 'should return true' do
            @accessible.should be_true
          end
        end
        
        context 'when user != current_user' do
          before do
            @accessible = @sproject.accessible?(FactoryGirl.create(:user)) 
          end
          
          it 'should return false' do
            @accessible.should be_false
          end
        end
      end
    end
  end
  
  describe 'get_divs' do
    before do
      @sproject = FactoryGirl.create(:sproject)
    end
    
    context 'when divs present' do
      before do
        @project_1 = FactoryGirl.create(:project)
        FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject.id)        
        @div_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 'div source_id')
      end
      
      context 'when same project included in self.projects & divs.project' do
        before do
          FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @div_1.id)        
          @divs = @sproject.get_divs(@div_1.sourceid)
        end
        
        it 'should return doc and nil notice' do
          @divs.should eql([[@div_1], nil])
        end
      end
      
      context 'when same project included in self.projects & divs.project' do
        before do
          FactoryGirl.create(:docs_project, :project_id => FactoryGirl.create(:project).id, :doc_id => @div_1.id)        
          @divs = @sproject.get_divs(@div_1.sourceid)
        end
        
        it 'should return doc and nil notice' do
          @divs.should eql([nil, I18n.t('controllers.application.get_divs.not_belong_to', :sourceid => @div_1.sourceid, :project_name => @sproject.name)])
        end
      end
    end
    
    context 'when divs blank' do
      before do
        @project_1 = FactoryGirl.create(:project)
        FactoryGirl.create(:projects_sproject, :project_id => @project_1.id, :sproject_id => @sproject.id)        
        @sourceid = 'sid'
        @divs = @sproject.get_divs(@sourceid)
      end
      
      it 'should return doc and nil notice' do
        @divs.should eql([nil, I18n.t('controllers.application.get_divs.no_annotation', :sourceid => @sourceid)])
      end
    end
  end
  
  describe 'increment_counters' do
    before do
      @sproject = FactoryGirl.create(:sproject,
        :pmdocs_count => 10,
        :pmcdocs_count => 20,
        :denotations_count => 30,
        :relations_count => 40
      )
      @project = FactoryGirl.create(:project,
        :pmdocs_count => 1,
        :pmcdocs_count => 2,
        :denotations_count => 3,
        :relations_count => 4
      )
      FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject.id)
      @sproject.increment_counters(@project)
    end
    
    it 'should increment sproject.counters' do
      @sproject.reload
      @sproject.pmdocs_count.should eql(11)
      @sproject.pmcdocs_count.should eql(22)
      @sproject.denotations_count.should eql(33)
      @sproject.relations_count.should eql(44)
    end
  end
end