# encoding: utf-8
require 'spec_helper'

describe Doc do
  describe 'has_many denotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @doc_denotation = FactoryGirl.create(:denotation, :doc => @doc, :project_id => 1)
      @another_denotation = FactoryGirl.create(:denotation, :doc => FactoryGirl.create(:doc))
    end
    
    it 'doc.denotations should include related denotation' do
      @doc.denotations.should include(@doc_denotation)
    end
    
    it 'doc.denotations should not include unrelated denotation' do
      @doc.denotations.should_not include(@another_denotation)
    end
  end
  
  describe 'has_many instances' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :project_id => 1)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 1)
    end
    
    it 'denotation.instances should present' do
      @denotation.instances.should be_present
    end
    
    it 'denotation.instances should include instance through denotations' do
      (@denotation.instances - [@instance]).should be_blank
    end
  end
  
  describe 'has_many :subcatrels' do
    before do
      @doc = FactoryGirl.create(:doc, :id => 2)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :id => 3, :project_id => 1)
      @subj = FactoryGirl.create(:denotation, :doc => @doc, :id => 4)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subcatrel = FactoryGirl.create(:subcatrel, :subj_id => @subj.id , :id => 4, :obj => @denotation)
    end
    
    it 'doc.denotations should include related denotation' do
      @doc.denotations.should include(@denotation)
    end

    it 'doc.subcatrels should include Relation which belongs_to @doc.denotation' do
      @doc.subcatrels.should include(@subcatrel)
    end
  end
  
  describe 'has_many subinsrels' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 1)
      @subinsrel = FactoryGirl.create(:relation,
        :subj_id => @instance.id,
        :subj_type => @instance.class.to_s,
        :obj_id => 20,
        :project_id => 30
      ) 
    end
    
    it 'doc.subinsrels should present' do
      @doc.subinsrels.should be_present
    end
    
    it 'doc.subinsrels include Relation thrhou instances' do
      (@doc.subinsrels - [@subinsrel]).should be_blank
    end
  end

  describe 'has_many insmods' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :project_id => 1)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 1)
      @insmod = FactoryGirl.create(:modification, :obj => @instance, :project_id => 5)
    end
    
    it 'doc.insmods should present' do
      @doc.insmods.should be_present
    end
    
    it 'doc.insmods should present' do
      (@doc.insmods - [@insmod]).should be_blank
    end
  end
  
  describe 'has_many subcatrelmods' do
    before do
      @doc = FactoryGirl.create(:doc, :id => 2)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :id => 3, :project_id => 1)
      @subj = FactoryGirl.create(:denotation, :doc => @doc, :id => 4)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subcatrel = FactoryGirl.create(:subcatrel, :subj_id => @subj.id , :id => 4, :obj => @denotation)
      @subcatrelmod = FactoryGirl.create(:modification, :obj => @subcatrel, :project => @project)
    end
    
    it 'doc.subcatrelmods should present' do
      @doc.subcatrels.should be_present
    end
    
    it 'doc.subcatrelmods should inclde modification through subcatrels' do
      (@doc.subcatrelmods - [@subcatrelmod]).should be_blank
    end
  end

  describe 'has_many :subinsrelmods' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :project_id => 1)
      @instance = FactoryGirl.create(:instance, :obj => @denotation, :project_id => 1)
      @subinsrel = FactoryGirl.create(:relation,
        :subj_id => @instance.id,
        :subj_type => @instance.class.to_s,
        :obj_id => 20,
        :project_id => 30
      )
      @subinsrelmod = FactoryGirl.create(:modification,
        :obj => @subinsrel,
        :project_id => 30
      )
    end
    
    it 'doc.subinsrelmods should present' do
      @doc.subinsrelmods.should be_present
    end
    
    it 'doc.subinsrelmods should inclde modification through subcatrels' do
      (@doc.subinsrelmods - [@subinsrelmod]).should be_blank
    end
  end
  
  
  describe 'has_and_belongs_to_many projects' do
    before do
      @doc_1 = FactoryGirl.create(:doc, :id => 3)
      @project_1 = FactoryGirl.create(:project, :id => 5, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :id => 7, :user => FactoryGirl.create(:user))
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc))
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
  
  describe 'scope' do
    describe 'pmdocs' do
      before do
        @pmdocs_count = 3
        @pmdocs_count.times do
          FactoryGirl.create(:doc, :sourcedb => 'PubMed')
        end
        @not_pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC')
        @pmdocs = Doc.pmdocs
      end
      
      it 'should match doc where sourcedb == PubMed size' do
        @pmdocs.size.should eql(@pmdocs_count)
      end
      
      it 'should not include document where sourcedb != PubMed' do
        @pmdocs.should_not include(@not_pmdoc)
      end
    end
    
    describe 'pmcdocs' do
      before do
        @pmcdocs_count = 3
        @pmcdocs_count.times do
          FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
        end
        @not_pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
        @serial_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 1)
        @pmcdocs = Doc.pmcdocs
      end
      
      it 'should match doc where sourcedb == PMC size' do
        @pmcdocs.size.should eql(@pmcdocs_count)
      end
      
      it 'should not include document where sourcedb != PMC' do
        @pmcdocs.should_not include(@not_pmcdoc)
      end
      
      it 'should not include document where serial != 0' do
        @pmcdocs.should_not include(@serial_1)
      end
    end
    
    describe 'project_name' do
      before do
        @project_1 = FactoryGirl.create(:project, :name => 'project_1')
        @doc_1 = FactoryGirl.create(:doc)
        FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
        @doc_2 = FactoryGirl.create(:doc)
        FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_2.id)
        @project_2 = FactoryGirl.create(:project, :name => 'project_2')
        @doc_3 = FactoryGirl.create(:doc)
        FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_3.id)
        @project_name = Doc.project_name(@project_1.name)
      end
      
      it '' do
        @project_name.should =~ [@doc_1, @doc_2]
      end
    end
  end
  
  describe 'self.order_by' do
    context 'same_sourceid_denotations_count' do
      before do
        @count_1 = double(:same_sourceid_denotations_count => 1)
        @count_2 = double(:same_sourceid_denotations_count => 2)
        @count_3 = double(:same_sourceid_denotations_count => 3)
        docs = [@count_1, @count_2, @count_3]
        @docs = Doc.order_by(docs, 'same_sourceid_denotations_count')
      end
      
      it 'docs.first should most same_sourceid_denotations_count' do
        @docs[0].should eql(@count_3)
      end
      
      it 'docs.first should second most same_sourceid_denotations_count' do
        @docs[1].should eql(@count_2)
      end
      
      it 'docs.first should least same_sourceid_denotations_count' do
        @docs.last.should eql(@count_1)
      end
    end
    
    context 'denotations_count' do
      before do
        @project = FactoryGirl.create(:project)
        @doc_denotations_3 = FactoryGirl.create(:doc, :id => 5)
        FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_3.id, :project_id => @project.id)
        3.times do
          FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_3)
        end
        @doc_denotations_2 = FactoryGirl.create(:doc, :id => 4)
        FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_2.id, :project_id => @project.id)
        2.times do
          FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_2)
        end
        @doc_denotations_1 = FactoryGirl.create(:doc, :id => 3)
        FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_1.id, :project_id => @project.id)
        FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_1)
        @doc_denotations_0 = FactoryGirl.create(:doc, :id => 2)
        @docs = Doc.order_by(Doc.all, 'denotations_count')
      end
      
      it 'doc which has most denotations should be docs[0]' do
        @docs[0].should eql(@doc_denotations_3)
      end
      
      it 'doc which has second most denotations should be docs[1]' do
        @docs[1].should eql(@doc_denotations_2)
      end
      
      it 'doc which has third most denotations should be docs[2]' do
        @docs[2].should eql(@doc_denotations_1)
      end
      
      it 'doc which does not has denotations should be docs.last' do
        @docs.last.should eql(@doc_denotations_0)
      end
    end
          
    context 'relations_count' do
      before do
        @doc_3relations = Doc.create(:id => 5)
        3.times do
          denotation = FactoryGirl.create(:denotation, :project_id => 1, :doc => @doc_3relations)
          FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
        end

        @doc_2relations = Doc.create(:id => 4)
        2.times do
          denotation = FactoryGirl.create(:denotation, :project_id => 2, :doc => @doc_2relations)
          FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
        end
        
        @doc_1relations = Doc.create(:id => 3)
        denotation = FactoryGirl.create(:denotation, :project_id => 3, :doc => @doc_1relations)
        FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
        
        @doc_0relations = Doc.create(:id => 2)
        @docs = Doc.order_by(Doc.all, 'relations_count')
      end
      
      it 'doc which has most relations should be docs[0]' do
        @docs[0].should eql(@doc_3relations)
      end
      
      it 'doc which has second most relations should be docs[0]' do
        @docs[1].should eql(@doc_2relations)
      end
      
      it 'doc which has third most relations should be docs[0]' do
        @docs[2].should eql(@doc_1relations)
      end
      
      it 'doc which does not has relations should be docs.last' do
        @docs[3].should eql(@doc_0relations)
      end
    end
    
    context 'same_sourceid_relations_count' do
      def create_same_sourceid_relations(doc, relations_size, instances_size)
        denotation = FactoryGirl.create(:denotation, :project_id => 1, :doc => doc)
        relations_size.times do
          FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => 'Denotation', :obj_id => denotation.id)
        end
        instances_size.times do |i|
          FactoryGirl.create(:instance, :obj_id => denotation.id, :project_id => 1)
        end
      end
      
      before do
        @relations_count2 = FactoryGirl.create(:doc,  :sourceid => 12345)
        create_same_sourceid_relations(@relations_count2, 1, 1)
        @relations_count3 = FactoryGirl.create(:doc,  :sourceid => 23456)
        create_same_sourceid_relations(@relations_count3, 1, 2)
        @relations_count4 = FactoryGirl.create(:doc,  :sourceid => 34567)
        create_same_sourceid_relations(@relations_count4, 3, 1)
        @relations_count0 = FactoryGirl.create(:doc,  :sourceid => 34567)
        @docs = Doc.order_by(Doc.all, 'same_sourceid_relations_count')
      end
      
      it 'doc which has 4 relations(same sourceid) should be docs[0]' do
        @docs[0].should eql(@relations_count0)
      end
      
      it 'doc which has 4 relations should be docs[1]' do
        @docs[1].should eql(@relations_count4)
      end
      
      it 'doc which has 3 relations should be docs[2]' do
        @docs[2].should eql(@relations_count3)
      end
      
      it 'doc which has 2 relations should be docs[3]' do
        @docs[3].should eql(@relations_count2)
      end
    end
    
    context 'else' do
      before do
        @doc_111 = FactoryGirl.create(:doc, :sourceid => 111)
        @doc_1111 = FactoryGirl.create(:doc, :sourceid => 1111)
        @doc_1112 = FactoryGirl.create(:doc, :sourceid => 1112)
        @doc_1211 = FactoryGirl.create(:doc, :sourceid => 1211)
        @doc_11111 = FactoryGirl.create(:doc, :sourceid => 11111)
        @docs = Doc.order_by(Doc.all, nil)
      end
      
      it 'sourceid 111 should be @docs[0]' do
        @docs[0].should eql(@doc_111)
      end
      
      it 'sourceid 1111 should be @docs[1]' do
        @docs[1].should eql(@doc_1111)
      end
      
      it 'sourceid 1112 should be @docs[2]' do
        @docs[2].should eql(@doc_1112)
      end
      
      it 'sourceid 1211 should be @docs[3]' do
        @docs[3].should eql(@doc_1211)
      end
      
      it 'sourceid 11111 should be @docs[4]' do
        @docs[4].should eql(@doc_11111)
      end
    end
  end
  
  describe 'project_relations_count' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project_relations_count = 3
      Relation.stub(:project_relations_count).and_return(@project_relations_count)
    end
    
    it 'should return project_relations_count values' do
      @doc.project_relations_count(nil).should eql(@project_relations_count * 2)
    end
  end
  
  describe 'relations_count' do
    before do
      @subcatrels_size = 1
      @subinsrels_size = 2
      Doc.any_instance.stub(:subcatrels).and_return(double({:size => @subcatrels_size}))
      Doc.any_instance.stub(:subinsrels).and_return(double({:size => @subinsrels_size}))
      @doc = FactoryGirl.create(:doc)
    end
    
    it 'should return subcatrels.size and subinsrels.size' do
      @doc.relations_count.should eql(@subcatrels_size + @subinsrels_size)
    end
  end
  
  describe 'same_sourceid_denotations_count' do
    before do
      @sourceid_1234_doc_has_denotations_count = 3
      @sourceid_1234_doc_has_denotations_count.times do
        doc = FactoryGirl.create(:doc, :sourceid => 1234)
        FactoryGirl.create(:denotation, :project_id => 1, :doc => doc)
      end
      @sourceid_1234 = FactoryGirl.create(:doc, :sourceid => 1234)
      
      @sourceid_4567_doc_has_denotations_count = 2
      @sourceid_4567_doc_has_denotations_count.times do
        doc = FactoryGirl.create(:doc, :sourceid => 4567)
        FactoryGirl.create(:denotation, :project_id => 1, :doc => doc)
      end
      @sourceid_4567 = FactoryGirl.create(:doc, :sourceid => 4567)
      @sourceid_1234_denotations_count = @sourceid_1234.same_sourceid_denotations_count
      @sourceid_4567_denotations_count = @sourceid_4567.same_sourceid_denotations_count
    end
    
    it 'should return docs which has samse sourceid denotations size' do
      @sourceid_1234_denotations_count.should eql(@sourceid_1234_doc_has_denotations_count)     
    end          
    
    it 'should return docs which has samse sourceid denotations size' do
      @sourceid_4567_denotations_count.should eql(@sourceid_4567_doc_has_denotations_count)     
    end          
  end
  
  describe 'same_sourceid_relations_count' do
    before do
      5.times do |i|
        id = i + 1
        doc = FactoryGirl.create(:doc, :id => id,  :sourceid => 123456)
        FactoryGirl.create(:denotation, :id => id, :project_id => 1, :doc => doc)
      end
      @doc = FactoryGirl.create(:doc,  :sourceid => 123456)

      @relations_size = 3
      @relations_size.times do |i|
        id = i + 1
        FactoryGirl.create(:relation, :subj_id => id, :subj_type => 'Denotation', :obj_id => id)
      end

      @instances_size = 2
      @instances_size.times do |i|
        id = i + 1
        FactoryGirl.create(:instance, :obj_id => id, :project_id => 1)
      end
    end
    
    it 'should returnarnersperspesazorder' do
      @doc.same_sourceid_relations_count.should eql(@relations_size + @instances_size)
    end
  end
end