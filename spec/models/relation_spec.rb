require 'spec_helper'

describe Relation do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @relation = FactoryGirl.create(:relation, :obj_id => 10, :project => @project)
    end
    
    it 'relation belongs to project' do
      @relation.project.should eql(@project)
    end
  end
  
  describe 'belongs_to subj polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @obj = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
    end
    
    context 'Denotation' do
      before do
        @subj = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :subj_id => @subj.id, :subj_type => @subj.class.to_s, :obj => @obj, :project => @project)
      end
      
      it 'relation.subj should equal Denotation' do
        @relation.subj.should eql(@subj)
      end
    end

    context 'Instance' do
      before do
        @subj = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :subj_id => @subj.id, :subj_type => @subj.class.to_s, :obj => @obj, :project => @project)
      end
      
      it 'relation.subj should equal Instance' do
        @relation.subj.should eql(@subj)
      end
    end
  end
  
  describe 'belongs_to obj polymorphic true' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @subj = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
    end
    
    context 'Denotation' do
      before do
        @obj = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @relation = FactoryGirl.create(:relation, :subj => @subj, :obj => @obj, :obj_type => @obj.class.to_s, :project => @project)
      end
      
      it 'relation.obj should equal Denotation' do
        @relation.obj.should eql(@obj)
      end
    end

    context 'Insaan' do
      before do
        @obj = FactoryGirl.create(:instance, :project => @project, :obj_id => 1)
        @relation = FactoryGirl.create(:relation, :subj => @subj, :obj => @obj, :obj_type => @obj.class.to_s, :project => @project)
      end
      
      it 'relation.subj should equal Instance' do
        @relation.obj.should eql(@obj)
      end
    end
  end
  
  describe 'has_many modifications' do
    before do
      @relation = FactoryGirl.create(:relation, :subj_id => 1, :obj_id => 2, :project_id => 1)
      @modification = FactoryGirl.create(:modification, :obj => @relation, :project_id => 1)
    end
    
    it 'relation.modifications should be present' do
      @relation.modifications.should be_present
    end
    
    it 'relation.modifications should include related modifications' do
      (@relation.modifications - [@modification]).should be_blank
    end
    
    it 'modification should belongs to relation' do
      @modification.obj.should eql(@relation)
    end
  end
  
  describe 'scope projects_reletions' do
    before do
      @relation_project_1 = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      @relation_project_2 = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 2)
      @relation_project_3 = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 3)
    end
    
    it 'should include project_id included in project_ids' do
      Relation.projects_relations([1,2]).should =~ [@relation_project_1, @relation_project_2]
    end
  end 
  
  describe 'project_pmcdoc_cat_relations' do
    before do
      @sourceid = 'pm123456'
      @project = FactoryGirl.create(:project)
      @pmc_doc_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @sourceid)
      @denotation_1 = FactoryGirl.create(:denotation, :doc => @pmc_doc_1, :project => @project)
      @relation_1 = FactoryGirl.create(:subcatrel, :obj => @denotation_1, :project => @project)
      @pmc_doc_2 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1, :sourceid => @sourceid)
      @denotation_2 = FactoryGirl.create(:denotation, :doc => @pmc_doc_2, :project => @project)
      @relation_2 = FactoryGirl.create(:subcatrel, :obj => @denotation_2, :project => @project)
      @pmc_doc_3 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 2, :sourceid => @sourceid)
      @denotation_3 = FactoryGirl.create(:denotation, :doc => @pmc_doc_3, :project => @project)
      @relation_3 = FactoryGirl.create(:subcatrel, :obj => @denotation_3, :project => @project)
    end
    
    it 'should return project_pmcdoc_cat_relations' do
      @project.relations.project_pmcdoc_cat_relations(@pmc_doc_1.sourceid).should =~ [@relation_1, @relation_2, @relation_3]
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @denotation_sub = FactoryGirl.create(:denotation, :id => 1, :hid => 'denotation sub hid', :project => @project, :doc => @doc)
      @denotation_obj = FactoryGirl.create(:denotation, :id => 2, :hid => 'denotation rel hid', :project => @project, :doc => @doc)
      @instance_subj = FactoryGirl.create(:instance, :obj_id => 1, :project => @project)
      @relation = FactoryGirl.create(:relation, 
      :hid => 'hid',
      :pred => '_lexChain', 
      :obj => @denotation_obj,
      :subj => @instance_subj, 
      :project => @project)
      @get_hash = @relation.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@relation[:hid])
    end
    
    it 'should set pred as type' do
      @get_hash[:pred].should eql(@relation[:pred])
    end
    
    it 'should set end as denotation:end' do
      @get_hash[:subj].should eql(@instance_subj[:hid])
    end
    
    it 'should set end as denotation:end' do
      @get_hash[:obj].should eql(@denotation_obj[:hid])
    end
  end
  
  describe 'validate' do
    context 'when subj == Denotation and obj == Instance' do
      before do
        @subj = FactoryGirl.create(:denotation,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:instance,
          :project_id => 1,
          :obj_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
      end
      
      it 'relation.subj should equal Denotation' do
        @subrel.subj.should eql(@subj)
      end
      
      it 'relation.obj should equal Instance' do
        @subrel.obj.should eql(@obj)
      end
    end    

    context 'when subj == Instance and obj == Denotation' do
      before do
        @subj = FactoryGirl.create(:instance,
          :project_id => 1,
          :obj_id => 2
        )
        @obj = FactoryGirl.create(:denotation,
          :project_id => 1,
          :doc_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
      end
      
      it 'relation.subj should equal Instance' do
        @subrel.subj.should eql(@subj)
      end
      
      it 'relation.subj should equal Denotation' do
        @subrel.obj.should eql(@obj)
      end
    end    

    context 'when subj and obj == Block' do
      before do
        @subj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @subrel = FactoryGirl.create(:relation,
          :subj_id => @subj.id,
          :subj_type => @subj.class.name,
          :obj => @obj,
          :obj_type => @obj.class.to_s,
          :project_id => 2
        )
        FactoryGirl.create(:relation, :subj_id => 10, :subj_type => @subj.class.name, :obj_id => 1, :project_id => 2)
      end
      
      it 'block should have subrels' do
        @subj.subrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@subj.subrels - [@subrel]).should be_blank
      end
      
      it 'block should have objrels' do
        @obj.objrels.should be_present
      end
      
      it 'block.subrels should have related relations' do
        (@obj.objrels - [@subrel]).should be_blank
      end
    end

    context 'when subj == Block subj != Block' do
      before do
        @subj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:denotation,
          :project_id => 1,
          :doc_id => 2
        )
      end
      
      it 'should raise error' do
        lambda { 
          FactoryGirl.create(:relation,
            :subj_id => @subj.id,
            :subj_type => @subj.class.name,
            :obj => @obj,
            :obj_type => @obj.class.to_s,
            :project_id => 2
          )
        }.should raise_error
      end
    end

    context 'when subj != Block obj == Block' do
      before do
        @subj = FactoryGirl.create(:denotation,
          :project_id => 1,
          :doc_id => 2
        )
        @obj = FactoryGirl.create(:block,
          :project_id => 1,
          :doc_id => 2
        )
      end
      
      it 'should raise error' do
        lambda { 
          FactoryGirl.create(:relation,
            :subj_id => @subj.id,
            :subj_type => @subj.class.name,
            :obj => @obj,
            :obj_type => @obj.class.to_s,
            :project_id => 2
          )
        }.should raise_error
      end
    end
  end
  
  describe 'self.project_relations_count' do
    before do
      @project = FactoryGirl.create(:project)
      @project_relations_count = 2
      @project_relations_count.times do
        FactoryGirl.create(:relation, :project => @project, :obj_id => 1)
      @another_project = FactoryGirl.create(:project)
      end
    end
    
    context 'when project have relations' do
      it 'should return denotations count' do
        Relation.project_relations_count(@project.id, Relation).should eql(@project_relations_count)
      end
    end
    
    context 'when project does not have relations' do
      it 'should return denotations count' do
        Relation.project_relations_count(@another_project.id, Relation).should eql(0)
      end
    end
  end
  
  describe 'scope accessible_projects' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      @project_accessibility_0_user_1 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_1)  
      @relation_accessibility_0_user_1 = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_0_user_1)
      @project_accessibility_1_user_1 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_1)  
      @relation_accessibility_1_user_1 = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_1_user_1)
      @project_accessibility_0_user_2 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_2)  
      @relation_accessibility_0_user_2 = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_0_user_2)
      @project_accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)  
      @relation_accessibility_1_user_2 = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_1_user_2)
      @project_accessibility_0_user_nil = FactoryGirl.create(:project, :accessibility => 0, :user_id => nil)  
      @relation_accessibility_0_user_nil = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_0_user_nil)
      @project_accessibility_1_user_nil = FactoryGirl.create(:project, :accessibility => 1, :user_id => nil)  
      @relation_accessibility_1_user_nil = FactoryGirl.create(:relation, :obj_id => 1, :project => @project_accessibility_1_user_nil)
    end
    
    context 'when current_user_id present' do
      before do
        @relations = Relation.accessible_projects(@user_1.id)
      end
    
      it 'includes accessibility = 1 and user is not current_user' do
        @relations.should include(@relation_accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1 and user is current_user' do
        @relations.should include(@relation_accessibility_1_user_1)
      end
      
      it 'includes accessibility = 1 and user is nil' do
        @relations.should include(@relation_accessibility_1_user_nil)
      end
      
      it 'not includes accessibility != 1 and user is not current_user' do
        @relations.should_not include(@relation_accessibility_0_user_2)
      end
      
      it 'includes accessibility != 1 and user is current_user' do
        @relations.should include(@relation_accessibility_0_user_1)
      end
      
      it 'not includes accessibility != 1 and user is nil' do
        @relations.should_not include(@relation_accessibility_0_user_nil)
      end
    end
    
    context 'when current_user_id nil' do
      before do
        @relations = Relation.accessible_projects(nil)
      end
    
      it 'includes accessibility = 1' do
        @relations.should include(@relation_accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1 ' do
        @relations.should include(@relation_accessibility_1_user_1)
      end
      
      it 'includes accessibility = 1 and user is nil' do
        @relations.should include(@relation_accessibility_1_user_nil)
      end
      
      it 'not includes accessibility != 1' do
        @relations.should_not include(@relation_accessibility_0_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @relations.should_not include(@relation_accessibility_0_user_1)
      end
      
      it 'not includes accessibility != 1' do
        @relations.select{|relation| relation.project.accessibility != 1}.should be_blank
      end
      
      it 'not includes accessibility != 1 and user is nil' do
        @relations.should_not include(@relation_accessibility_0_user_nil)
      end
    end
  end
  
  describe 'scope sql' do
    before do
      2.times do
        FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      end
      @relation_1 = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      @relation_2 =FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      @current_user = FactoryGirl.create(:user)
      @ids = [@relation_1.id, @relation_2.id]
      @relations = Relation.sql(@ids)
    end
    
    it 'should include id matched and order by id ASC' do
      @relations = [@relation_1, @relation_2]
    end    
  end
  
  describe 'increment_subcatrels_count' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :project_id => 1, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 1)
      @subcatrels_count = 3
    end
    
    context 'when subj == Denotations' do
      before do
        @subcatrels_count.times do
          FactoryGirl.create(:subcatrel, :obj => @instance)
        end
        @doc.reload
      end
      
      it 'should count up subcatrels_count' do
        @doc.subcatrels_count.should eql(@subcatrels_count)
      end
    end
    
    context 'when subj != Denotations' do
      before do
        @subcatrels_count.times do
          FactoryGirl.create(:relation, :project_id => 1, :obj => @instance)
        end
        @doc.reload
      end
      
      it 'should not count up subcatrels_count' do
        @doc.subcatrels_count.should eql(0)
      end
    end
  end

  describe 'sql_find' do
    before do
      @current_user = FactoryGirl.create(:user)
      @accessible_relation = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      @project_relation = FactoryGirl.create(:relation, :obj_id => 1, :project_id => 1)
      @project = FactoryGirl.create(:project)
      # stub scope and return all Doc
      @accessible_projects = Relation.where(:id => @accessible_relation.id)
      Relation.stub(:accessible_projects).and_return(@accessible_projects)
      @project_relations = Relation.where(:id => @project_relation.id)
      Relation.stub(:projects_relations).and_return(@project_relations)
    end
    
    context 'when params[:sql] present' do
      before do
        @params = {:sql => 'select * from relations;'}
      end
      
      context 'when current_user present' do
        context 'when results present' do
          context 'when project present' do
            before do
              @relations = Relation.sql_find(@params, @current_user, @project)
            end
            
            it 'should return sql result refined by scope project_relations' do
              @relations.should =~ @project_relations
            end
          end
  
          context 'when project blank' do
            before do
              @relations = Relation.sql_find(@params, @current_user, nil)
            end
            
            it 'should return sql result refined by scope accessible_projects' do
              @relations.should =~ @accessible_projects
            end
          end
        end
        
        context 'when results present' do
          it 'should return nil' do
            Relation.sql_find({:sql => 'select * from relations where id = 1000'}, @current_user, @project).should be_nil
          end
        end
      end
      
      context 'when current_user nil' do
        context 'when results present' do
          context 'when project present' do
            before do
              @relations = Relation.sql_find(@params, nil, @project)
            end
            
            it 'should return sql result refined by scope project_relations' do
              @relations.should =~ @project_relations
            end
          end
  
          context 'when project blank' do
            before do
              @relations = Relation.sql_find(@params, nil, nil)
            end
            
            it 'should return sql result refined by scope accessible_projects' do
              @relations.should =~ @accessible_projects
            end
          end
        end
        
        context 'when results present' do
          it 'should return nil' do
            Relation.sql_find({:sql => 'select * from relations where id = 1000'}, nil, @project).should be_nil
          end
        end
      end
    end
    
    context 'when params[:sql] blank' do
      it 'should return nil' do
       Doc.sql_find({}, @current_user, @project).should be_nil
      end
    end
  end
  
  describe 'increment_project_relations_count' do
    before do
      @project = FactoryGirl.create(:project, :relations_count => 0)
      @associate_project_1 = FactoryGirl.create(:project, :relations_count => 0)
      @associate_project_2 = FactoryGirl.create(:project, :relations_count => 0)
      @associate_project_2_relations_count = 1
      @associate_project_2_relations_count.times do
        FactoryGirl.create(:relation, :project => @associate_project_2, :obj_id => 1)
      end     
      @associate_project_2.reload      
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @project.reload
      @associate_project_2.reload
      @relation = FactoryGirl.create(:relation, :project => @associate_project_2, :obj_id => 2)
      @associate_project_2.reload
      @project.reload
    end
    
    it 'should increment project.relations_count' do
      @project.relations_count.should eql((@associate_project_2_relations_count * 2) + 1)
    end      
    
    it 'should increment project.relations_count' do
      @associate_project_1.relations_count.should eql(0)
    end      
    
    it 'should increment project.relations_count' do
      @associate_project_2.relations_count.should eql(2)
    end      
  end  
end