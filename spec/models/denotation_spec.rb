require 'spec_helper'

describe Denotation do
  describe 'belongs_to doc' do
    let( :doc ) { FactoryGirl.create(:doc) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc: doc) }

    it 'should belongs_to doc' do
      expect( denotation.doc ).to eql(doc)
    end

    it 'doc should count up doc.denotations_count' do
      doc.reload
      denotation.reload
      expect( doc.denotations_count ).to eql(1)
    end  
  end

  describe 'has_many modifications' do
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc_id: 1) }
    let( :instance) { FactoryGirl.create(:instance, obj: denotation, project: project) }
    let( :modification) { FactoryGirl.create(:modification, obj_type: 'Denotation', obj: denotation) }

    it 'should include modification as modifications' do
      expect( denotation.modifications ).to include(modification)
    end

    it 'modification should belongs_to denotation as obj' do
      expect( modification.obj ).to eql(denotation)
    end
  end

  describe 'has_many subrels' do
    let( :user ) { FactoryGirl.create(:user) }
    let( :project ) { FactoryGirl.create(:project, user: user) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc_id: 1) }
    let( :relation) { FactoryGirl.create(:relation, subj_type: 'Annotation', subj_id: denotation.id, obj_id: 1, project: project) }

    it 'should has_many subrels' do
      expect( denotation.subrels ).to include(relation)
    end
  end

  describe 'has_many obrels' do
    let( :user ) { FactoryGirl.create(:user) }
    let( :project ) { FactoryGirl.create(:project, user: user) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc_id: 1) }
    let( :relation) { FactoryGirl.create(:relation, subj_type: 'Modification', subj_id: denotation.id, obj_type: 'Annotation', obj_id: denotation.id, project: project) }

    it 'should has_many objrels' do
      expect( denotation.objrels ).to include(relation)
    end
  end
  
  describe 'has_many projects through annotations_projects' do
    let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let( :denotation ) { FactoryGirl.create(:denotation, doc_id: 1) }
    let( :annotations_project) { FactoryGirl.create(:annotations_project, annotation: denotation, project: project) }
    
    it 'denotation.should belongs to project' do
      annotations_project.reload
      denotation.reload
      denotation.projects.should include(project)
    end
  end
  
  describe 'scope' do
    describe 'from_projects' do
      let( :denotation_1 ) { FactoryGirl.create(:denotation, doc_id: 1) }
      let( :denotation_2 ) { FactoryGirl.create(:denotation, doc_id: 1) }
      let( :project_1 ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
      let( :project_2 ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
      let( :annotations_project_1) { FactoryGirl.create(:annotations_project, annotation: denotation_1, project: project_1) }
      let( :annotations_project_2) { FactoryGirl.create(:annotations_project, annotation: denotation_1, project: project_2) }
      let( :annotations_project_3) { FactoryGirl.create(:annotations_project, annotation: denotation_2, project: project_2) }

      before do
        annotations_project_1.reload
        annotations_project_2.reload
        annotations_project_3.reload
      end

      it 'should include denotation belongs_to project' do
        expect( Denotation.from_projects([project_1, project_2]) ).to include(denotation_1)
      end

      it 'should include denotation belongs_to project' do
        expect( Denotation.from_projects([project_1, project_2]) ).to include(denotation_2)
      end
    end

    describe 'within_span' do
      before do
        @denotation_0_9 = FactoryGirl.create(:denotation, :doc_id => 1, :begin => 0, :end => 9)
        @denotation_5_15 = FactoryGirl.create(:denotation, :doc_id => 2, :begin => 5, :end => 15)
        @denotation_10_15 = FactoryGirl.create(:denotation, :doc_id => 3, :begin => 10, :end => 15)
        @denotation_10_19 = FactoryGirl.create(:denotation, :doc_id => 4, :begin => 10, :end => 19)
        @denotation_10_20 = FactoryGirl.create(:denotation, :doc_id => 4, :begin => 10, :end => 20)
        @denotation_15_19 = FactoryGirl.create(:denotation, :doc_id => 5, :begin => 15, :end => 19)
        @denotation_15_25 = FactoryGirl.create(:denotation, :doc_id => 6, :begin => 15, :end => 25)
        @denotation_20_30 = FactoryGirl.create(:denotation, :doc_id => 7, :begin => 20, :end => 30)
        @denotations = Denotation.within_span({:begin => 10, :end => 20})
      end
      
      it 'should not include begin and end are out of spans' do
        @denotations.should_not include(@denotation_0_9)
      end
      
      it 'should not include begin is out of spans' do
        @denotations.should_not include(@denotation_5_15)
      end
      
      it 'should include begin and end are within of spans' do
        @denotations.should include(@denotation_10_15)
      end
      
      it 'should include begin and end are within of spans' do
        @denotations.should include(@denotation_10_19)
      end
      
      it 'should include begin and end are within of spans' do
        @denotations.should include(@denotation_10_20)
      end
      
      it 'should include begin and end are within of spans' do
        @denotations.should include(@denotation_15_19)
      end
      
      it 'should not include end is within of spans' do
        @denotations.should_not include(@denotation_15_25)
      end
    end

    describe 'accessible_projects' do
      before do
        # User
        @current_user = FactoryGirl.create(:user)
        Denotation.stub(:current_user).and_return(@current_user)
        @another_user = FactoryGirl.create(:user)
        # Project
        @current_user_project_1 = FactoryGirl.create(:project, :user => @current_user, :accessibility => 0)
        @current_user_project_2 = FactoryGirl.create(:project, :user => @current_user, :accessibility => 0)
        @another_user_project_1 = FactoryGirl.create(:project, :user => @another_user, :accessibility => 0)
        @another_user_project_accessible = FactoryGirl.create(:project, :user => @another_user, :accessibility => 1)
        # Doc
        @doc_1 = FactoryGirl.create(:doc)
        @doc_2 = FactoryGirl.create(:doc)
        @doc_3 = FactoryGirl.create(:doc)
        @doc_4 = FactoryGirl.create(:doc)
        
        # Denotation
        @current_user_project_denotation_1 = FactoryGirl.create(:denotation, :doc => @doc_1)
        FactoryGirl.create(:annotations_project, project: @current_user_project_1, annotation: @current_user_project_denotation_1)
        @current_user_project_denotation_2 = FactoryGirl.create(:denotation, :doc => @doc_2)
        FactoryGirl.create(:annotations_project, project: @current_user_project_2, annotation: @current_user_project_denotation_2)
        @current_user_project_denotation_no_doc = FactoryGirl.create(:denotation, :doc_id => 100000)
        FactoryGirl.create(:annotations_project, project: @current_user_project_2, annotation: @current_user_project_denotation_no_doc)
        @another_user_project_denotation_1 = FactoryGirl.create(:denotation, :doc => @doc_3)
        FactoryGirl.create(:annotations_project, project: @current_user_project_1, annotation: @current_user_project_denotation_1)
        @another_user_accessible_project_denotation = FactoryGirl.create(:denotation, :doc => @doc_4)
        FactoryGirl.create(:annotations_project, project: @another_user_project_accessible, annotation: @another_user_accessible_project_denotation)
        
        ids = Denotation.all.collect{|d| d.id}
      end
      
      context 'when current_user_id present' do
        before do
          @denotations = Denotation.accessible_projects(@current_user.id)
        end
              
        it "should include denotations belongs to accessibility = 0 and current user's project" do
          @denotations.should include(@current_user_project_denotation_1)
          @denotations.should include(@current_user_project_denotation_2)
        end
        
        it "should not include denotations doc is nil" do
          @denotations.should_not include(@current_user_project_denotation_no_doc)
        end
        
        it "should include denotations belongs to another users's project which accessibility == 1" do
          @denotations.should include(@another_user_accessible_project_denotation)
        end
        
        it "should not include denotations belongs to another users's project which accessibility != 1" do
          @denotations.should_not include(@another_user_project_denotation_1)
        end
      end
      
      context 'when current_user_id present' do
        before do
          @denotations = Denotation.accessible_projects(nil)
        end
              
        it "should include denotations belongs to accessibility = 0 and current user's project" do
          @denotations.should_not include(@current_user_project_denotation_1)
          @denotations.should_not include(@current_user_project_denotation_2)
        end
        
        it "should not include denotations doc is nil" do
          @denotations.should_not include(@current_user_project_denotation_no_doc)
        end
        
        it "should include denotations belongs to another users's project which accessibility == 1" do
          @denotations.should include(@another_user_accessible_project_denotation)
        end
        
        it "should not include denotations belongs to another users's project which accessibility != 1" do
          @denotations.should_not include(@another_user_project_denotation_1)
        end
      end
    end 
    
    describe 'sql' do
      before do
        @denotation_1 = FactoryGirl.create(:denotation, :doc_id => 1)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: @denotation_1.id)
        @denotation_2 = FactoryGirl.create(:denotation, :doc_id => 1)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: @denotation_2.id)
        @denotation_3 = FactoryGirl.create(:denotation, :doc_id => 1)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: @denotation_3.id)
        denotation_4 = FactoryGirl.create(:denotation, :doc_id => 1)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: denotation_4.id)
        @denotations = Denotation.sql([@denotation_1.id, @denotation_2.id])
      end
      
      it 'should include id matched and order by id ASC' do
        @denotations = [@denotation_1, @denotation_2]
      end
    end  
  end
  
  describe 'get_hash' do
    before do
      @denotation = FactoryGirl.create(:denotation,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :obj => 'obj',
        :doc_id => 3
      )
    end
    
    context 'when called' do
      before do
        @get_hash = @denotation.get_hash
      end

      it 'should set hid as id' do
        @get_hash[:id].should eql(@denotation[:hid])
      end
      
      it 'should set begin as denotation:begin' do
        @get_hash[:span][:begin].should eql(@denotation[:begin])
      end
      
      it 'should set end as denotation:end' do
        @get_hash[:span][:end].should eql(@denotation[:end])
      end
      
      it 'should set obj as obj' do
        @get_hash[:obj].should eql(@denotation[:obj])
      end
    end
  end

  describe 'after_save' do
    before do
      Denotation.any_instance.stub(:update_projects_after_save).and_return(nil)
      @denotation = FactoryGirl.build(:denotation, doc_id: 1) 
    end

    it 'should exec update_projects_after_save' do
      @denotation.should_receive(:update_projects_after_save)
      @denotation.save
    end
  end

  describe 'after_destroy' do
    before do
      Denotation.any_instance.stub(:decrement_project_annotations_count).and_return(nil)
      Denotation.any_instance.stub(:update_projects_after_save).and_return(nil)
      Denotation.any_instance.stub(:update_projects_before_destroy).and_return(nil)
      @denotation = FactoryGirl.create(:denotation, doc_id: 1) 
    end

    it 'should exec update_projects_after_save' do
      @denotation.should_receive(:decrement_project_annotations_count)
      @denotation.destroy
    end
  end
  
  # TODO
  describe 'update_projects_after_save' do
    before do
      Project.any_instance.stub(:increment_counters).and_return(nil)
      Project.any_instance.stub(:copy_associate_project_relational_models).and_return(nil)
      @annotations_updated_at = 10.days.ago
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0, :annotations_updated_at => @annotations_updated_at, updated_at: @updated_at)
      @associate_project_1 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_2 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_2_denotations_count = 1
      @doc = FactoryGirl.create(:doc)
      @associate_project_2.docs << @doc
      @associate_project_2_denotations_count.times do
        annotation = FactoryGirl.create(:denotation, :doc_id => @doc.id)
        FactoryGirl.create(:annotations_project, project: @associate_project_2, annotation: annotation)
      end
      @associate_project_2.reload
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @associate_project_1.reload
      @associate_project_2.reload
      @project.reload
    end
    
    describe 'before create' do
      it 'project.denotations_count should qeual associate_projects' do
        @project.denotations_count.should eql(@associate_project_2_denotations_count * 2)
      end
      
      it 'should not increment associate_project.denotations_count' do
        @associate_project_1.denotations_count.should eql(0)
      end      
      
      it 'should not increment associate_project.denotations_count' do
        @associate_project_2.denotations_count.should eql(1)
      end     
    end     
    
    describe 'after create' do
      before do
        @denotation = FactoryGirl.create(:denotation, :doc_id => 1)
        FactoryGirl.create(:annotations_project, project: @associate_project_2, annotation: @denotation)
        @project.reload
        @associate_project_1.reload
        @associate_project_2.reload
        @project_stub = double('Project') 
        Project.stub(:where).and_return(@project_stub)
      end
          
      it 'should increment project.denotations_count' do
        @project.denotations_count.should eql((@associate_project_2_denotations_count * 2) + 1)
      end      
          
      
      it 'should increment associate_project.denotations_count' do
        @associate_project_1.denotations_count.should eql(0)
      end      
      
      it 'should increment associate_project.denotations_count' do
        @associate_project_2.denotations_count.should eql(2)
      end 
      
      it 'should update project.annotations_updated_at' do
        @project.annotations_updated_at.utc.should_not eql( @annotations_updated_at.utc )
      end     
    end      

    describe 'update project.updated_at' do
      let( :project_stub ) { double('Project')  }
      let( :updated_at ) { 10.days.ago }
      let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0, updated_at: updated_at) }

      it 'should update project.updated_at' do
        FactoryGirl.create(:denotation, :project => project, :doc_id => 1)
        project.reload
        expect(project.updated_at).not_to eql(updated_at)
      end      
    end
  end

  describe '#increment_project_annotations_count' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project) 
      @project.reload
    end

    it 'should increment project.annotations_count' do
      expect{  
        @denotation.increment_project_annotations_count
        @project.reload
      }.to change{ @project.annotations_count }.from(1).to(2)
    end
  end

  describe 'update_projects_before_destroy' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_1 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_2 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_2_denotations_count = 1
      @doc = FactoryGirl.create(:doc)
      @associate_project_2.docs << @doc      
      @di = 1
      @associate_project_2_denotations_count.times do
        denotation = FactoryGirl.create(:denotation, :begin => @di, :doc_id => @doc.id)
        FactoryGirl.create(:annotations_project, project: @associate_project_2, annotation: denotation)
        @di += 1
      end
      @associate_project_2.reload
      @denotation = FactoryGirl.create(:denotation, :begin => @di, :doc_id => @doc.id)
      FactoryGirl.create(:annotations_project, project: @associate_project_2, annotation: @denotation)
      @associate_project_1.reload
      @associate_project_2.reload
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @project.reload
    end
    
    describe 'before create' do
      it 'project.denotations_count should equal associate_projects' do
        @project.denotations_count.should eql(@associate_project_2.denotations.count * 2)
      end
      
      it 'should not increment associate_project.denotations_count' do
        @associate_project_1.denotations_count.should eql(0)
      end      
      
      it 'should not increment associate_project.denotations_count' do
        @associate_project_2.denotations_count.should eql(2)
      end     
    end     
    
    describe 'after create' do
      before do
        @denotation.destroy
        @project.reload
        @associate_project_1.reload
        @associate_project_2.reload
      end
          
      it 'should increment project.denotations_count' do
        @project.denotations_count.should eql(@associate_project_2_denotations_count *2 + (1 *2) -1)
      end      
      
      it 'should increment associate_project.denotations_count' do
        @associate_project_1.denotations_count.should eql(0)
      end      
      
      it 'should increment associate_project.denotations_count' do
        @associate_project_2.denotations_count.should eql(1)
      end      
    end      

    describe 'update project.updated_at' do
      let( :project_stub ) { double('Project')  }
      let( :updated_at ) { 10.days.ago }
      let( :project ) { FactoryGirl.create(:project, user: FactoryGirl.create(:user), :denotations_count => 0, updated_at: updated_at) }
      let( :denotation ) { FactoryGirl.create(:denotation, :project => project, :doc_id => 1) }

      it 'should update project.updated_at' do
        denotation.destroy
        project.reload
        expect(project.updated_at).not_to eql(updated_at)
      end      
    end
  end
  

  describe 'decrement_project_annotations_count' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, doc_id: 1) 
      FactoryGirl.create(:annotations_project, project: @project, annotation: @denotation)
      @project.reload
    end

    it 'should decrement project.annotations_count' do
      expect{  
        @denotation.decrement_project_annotations_count
        @project.reload
      }.to change{ @project.annotations_count }.from(1).to(0)
    end
  end
  
  describe 'self.sql_find' do
    pending do
      before do
      end
      
      context 'when params[:sql] present' do
        before do
          @current_user = FactoryGirl.create(:user)
          @sql = 'select * from denotations;'
          @params = {:sql => @sql}
          @accessible_denotation = FactoryGirl.create(:denotation, :project_id => 1)  
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @project_denotation = FactoryGirl.create(:denotation, :project => @project)  
          Denotation.stub(:accessible_projects).and_return(Denotation.where(:id => @accessible_denotation.id))
          Denotation.stub(:projects_denotations).and_return(Denotation.where(:id => @project_denotation.id))
        end
        
        context 'when current_user blank' do
          context 'when results.present' do
            context 'when project.present' do
              before do
                @denotations = Denotation.sql_find(@params, nil, @project)
              end
              
              it "should return project's denotations" do
                @denotations.should =~ [@project_denotation]
              end
            end
            
            context 'when project.blank' do
              before do
                @denotations = Denotation.sql_find(@params, nil, nil)
              end
              
              it "should return accessible project's denotations" do
                @denotations.should =~ [@accessible_denotation]
              end
            end
          end
        end
        
        context 'when current_user present' do
          context 'when results.present' do
            context 'when project.present' do
              before do
                @denotations = Denotation.sql_find(@params, @current_user, @project)
              end
              
              it "should return project's denotations" do
                @denotations.should =~ [@project_denotation]
              end
            end
            
            context 'when project.blank' do
              before do
                @denotations = Denotation.sql_find(@params, @current_user, nil)
              end
              
              it "should return accessible project's denotations" do
                @denotations.should =~ [@accessible_denotation]
              end
            end
          end
        end
      end

      context 'when params[:sql] blank' do
        before do
          @denotations = Denotation.sql_find({}, nil, nil)
        end
        
        it 'should return blank' do
          @denotations.should be_blank
        end
      end
    end
  end
end
