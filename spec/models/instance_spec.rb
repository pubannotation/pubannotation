require 'spec_helper'

describe Instance do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project => @project)
    end
    
    it 'instance belongs to project' do
      @instance.project.should eql(@project)
    end
  end

  describe 'belongs_to obj' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project => @project)
    end
    
    it 'instance belongs to obj' do
      @instance.obj.should eql(@denotation)
    end
  end
  
  describe 'has_many subrels' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
      @instance = FactoryGirl.create(:instance, :project => @project, :obj => @denotation)
      @relation = FactoryGirl.create(:relation, :subj_id => @instance.id, :subj_type => @instance.class.to_s, :obj => @denotation, :project => @project)
      FactoryGirl.create(:relation, :subj_id => 20, :subj_type => @instance.class.to_s, :obj => @denotation, :project => @project)
    end
    
    it 'instance has subrels' do
      @instance.subrels.should be_present
    end
    
    it 'instance should have Relation class as subrels' do
      @instance.subrels.first.class.should eql(Relation)
    end
    
    it 'instance should include related subrels' do
      (@instance.subrels - [@relation]).should be_blank
    end
  end
  
  describe 'has_many objrels' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => FactoryGirl.create(:doc))
      @instance = FactoryGirl.create(:instance, :project => @project, :obj => @denotation)
      @relation = FactoryGirl.create(:relation, :subj_id => @denotation.id, :subj_type => @denotation.class.to_s, :obj => @instance, :obj_type => @instance.class.to_s, :project => @project)
      FactoryGirl.create(:relation, :subj_id => @denotation.id, :subj_type => @denotation.class.to_s, :obj => @denotation, :obj_type => @denotation.class.to_s, :project => @project)
    end
    
    it 'instance should have objrels' do
      @instance.objrels.should be_present
    end
    
    it 'instance should include related objrels' do
      (@instance.objrels - [@relation]).should be_blank 
    end
  end
  
  describe 'has_many modifications' do
    before do
      @instance = FactoryGirl.create(:instance, :project => FactoryGirl.create(:project, :user => FactoryGirl.create(:user)), :obj => FactoryGirl.create(:denotation))
      @instance_2 = FactoryGirl.create(:instance, :project => FactoryGirl.create(:project, :user => FactoryGirl.create(:user)), :obj => FactoryGirl.create(:denotation))
      @modification = FactoryGirl.create(:modification, :obj => @instance, :project => FactoryGirl.create(:project, :user => FactoryGirl.create(:user)))
      FactoryGirl.create(:modification, :obj => @instance_2, :project => FactoryGirl.create(:project, :user => FactoryGirl.create(:user)))
    end
    
    it 'instance should have modifications' do
      @instance.modifications.should be_present
    end
    
    it 'instance should have include related modification' do
      (@instance.modifications - [@modification]).should be_blank
    end
  end
  
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance,
        :hid => 'hid',
        :pred => 'pred',
        :obj => @denotation,
        :project => @project
      )
      @get_hash = @instance.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@instance[:hid])
    end
    
    it 'should set pred as type' do
      @get_hash[:pred].should eql(@instance[:pred])
    end
    
    it 'should set hid as object' do
      @get_hash[:obj].should eql(@denotation[:hid])
    end
  end
end
