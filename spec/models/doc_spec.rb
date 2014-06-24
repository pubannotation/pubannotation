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
  
  describe 'has_many :subcatrels' do
    before do
      @doc = FactoryGirl.create(:doc)
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
  end
  
  describe 'has_many subcatrelmods' do
    before do
      @doc = FactoryGirl.create(:doc)
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
  end
  
  
  describe 'has_and_belongs_to_many projects' do
    before do
      @doc_1 = FactoryGirl.create(:doc)
      @project_1 = FactoryGirl.create(:project, :id => 5, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :id => 7, :user => FactoryGirl.create(:user))
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
  
  describe 'scope projects_docs' do
    before do
      @project_1 = FactoryGirl.create(:project)
      @doc_1 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      @project_2 = FactoryGirl.create(:project)
      @doc_2 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_2.id)
      @project_3 = FactoryGirl.create(:project)
      @doc_3 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_3.id, :doc_id => @doc_3.id)
      @projects_docs = Doc.projects_docs([@project_1.id, @project_2.id]) 
    end
    
    it 'should return docs belongs to projects' do
      @projects_docs.should =~ [@doc_1, @doc_2]
    end
  end
  
  describe 'source_dbs' do
    before do
      @project = FactoryGirl.create(:project)
      # create docs belongs to project
      @project_doc_1 = FactoryGirl.create(:doc, :sourcedb => "sourcedb1")
      @project_doc_2 = FactoryGirl.create(:doc, :sourcedb => "sourcedb2")
      # create docs not belongs to project
      2.times do
        FactoryGirl.create(:doc, :sourcedb => 'sdb')
      end
      @docs = Doc.source_dbs   
    end
    
    it 'should not include sourcedb is nil or blank' do
      @docs.select{|doc| doc.sourcedb == nil || doc.sourcedb == ''}.should be_blank
    end
  end
  
  describe 'accessible_projects' do
    before do
      @user_1 = FactoryGirl.create(:user)
      @user_2 = FactoryGirl.create(:user)
      @project_accessibility_0_user_1 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_1)  
      @doc_accessibility_0_user_1 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :doc_id => @doc_accessibility_0_user_1.id , :project_id => @project_accessibility_0_user_1.id)  
      @project_accessibility_1_user_1 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_1)  
      @doc_accessibility_1_user_1 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :doc_id => @doc_accessibility_1_user_1.id , :project_id => @project_accessibility_1_user_1.id)  
      @project_accessibility_0_user_2 = FactoryGirl.create(:project, :accessibility => 0, :user => @user_2)  
      @doc_accessibility_0_user_2 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :doc_id => @doc_accessibility_0_user_2.id , :project_id => @project_accessibility_0_user_2.id)  
      @project_accessibility_1_user_2 = FactoryGirl.create(:project, :accessibility => 1, :user => @user_2)  
      @doc_accessibility_1_user_2 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :doc_id => @doc_accessibility_1_user_2.id , :project_id => @project_accessibility_1_user_2.id)  
    end
    
    context 'when current_user_id present' do
      before do
        @docs = Doc.accessible_projects(@user_1.id)
      end
      
      it 'includes accessibility = 1 and user is not current_user' do
        @docs.should include(@doc_accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1 and user is current_user' do
        @docs.should include(@doc_accessibility_1_user_1)
      end
      
      it 'not includes accessibility != 1 and user is not current_user' do
        @docs.should_not include(@doc_accessibility_0_user_2)
      end
      
      it 'includes accessibility != 1 and user is current_user' do
        @docs.should include(@doc_accessibility_0_user_1)
      end
    end
    
    context 'when current_user_id nil' do
      before do
        @docs = Doc.accessible_projects(nil)
      end
      
      it 'includes accessibility = 1' do
        @docs.should include(@doc_accessibility_1_user_2)
      end
      
      it 'includes accessibility = 1' do
        @docs.should include(@doc_accessibility_1_user_1)
      end
      
      it 'not includes accessibility != 1' do
        @docs.should_not include(@doc_accessibility_0_user_2)
      end
      
      it 'not includes accessibility != 1' do
        @docs.should_not include(@doc_accessibility_0_user_1)
      end
      
      it 'not includes accessibility != 1' do
        @docs.collect{|doc| doc.projects}.flatten.uniq.select{|project| project.accessibility != 1}.should be_blank
      end      
    end
  end 
  
  describe 'scope sql' do
    before do
      2.times do
        FactoryGirl.create(:doc)
      end
      @doc_1 = FactoryGirl.create(:doc)
      @doc_2 = FactoryGirl.create(:doc)
      @current_user = FactoryGirl.create(:user)
      @ids = [@doc_1.id, @doc_2.id]
      @docs = Doc.sql(@ids)
    end
    
    it 'should include id matched and order by id ASC' do
      @docs = [@doc_1, @doc_2]
    end
  end 
  
  describe 'source_db_id' do
    before do
      @doc_sourcedb_uniq = FactoryGirl.create(:doc, :sourcedb => 'Uniq1', :sourceid => '11')
      @doc_sourceid_uniq_1 = FactoryGirl.create(:doc, :sourcedb => 'Uniq2', :sourceid => '10')
      @doc_sourceid_uniq_2 = FactoryGirl.create(:doc, :sourcedb => 'Uniq2', :sourceid => '123')
    end
    
    context 'when order_key_method nil' do
      before do
        @docs = Doc.source_db_id(nil)
      end
      
      it 'should include has no same sourcedb docs' do
        @docs.should include(@doc_sourcedb_uniq)
      end
      
      it 'should include has no same sourcedb docs' do
        @docs.should include(@doc_sourceid_uniq_2)
      end
      
      it 'should order by sourcedb ASC sourceid ASC' do
        @docs.first.should eql @doc_sourcedb_uniq
      end
      
      it 'should order by sourcedb ASC sourceid ASC' do
        @docs.second.should eql @doc_sourceid_uniq_1
      end
      
      it 'should order by sourcedb ASC sourceid ASC' do
        @docs.last.should eql @doc_sourceid_uniq_2
      end
    end
    
    context 'when order_key sourcedb method DESC' do
      before do
        @docs = Doc.source_db_id('sourcedb DESC')
      end
      
      it 'should order by sourcedb DESC' do
        @docs.last.should eql @doc_sourcedb_uniq
      end
      
      it 'should order by sourcedb DESC' do
        @docs.first.should eql @doc_sourceid_uniq_1
      end
      
      it 'should order by sourcedb DESC' do
        @docs.second.should eql @doc_sourceid_uniq_2
      end
    end
    
    context 'when order_key sourceid_int method DESC' do
      before do
        @docs = Doc.source_db_id('sourceid_int DESC')
      end
      
      it 'should order by sourceid_int DESC' do
        @docs.second.should eql @doc_sourcedb_uniq
      end
      
      it 'should order by sourceid_int DESC' do
        @docs.last.should eql @doc_sourceid_uniq_1
      end
      
      it 'should order by sourceid_int DESC' do
        @docs.first.should eql @doc_sourceid_uniq_2
      end
    end
  end

  describe 'sort_by_params' do
    before do
      @doc_1 = FactoryGirl.create(:doc)
      @doc_2 = FactoryGirl.create(:doc)
      @doc_3 = FactoryGirl.create(:doc)
    end

    context 'when sort_order is id DESC' do
      before do
        @docs = Doc.sort_by_params([['id DESC']])
      end

      it 'should sort doc by sort_order' do
        @docs.first.should eql @doc_3
      end

      it 'should sort doc by sort_order' do
        @docs.second.should eql @doc_2
      end
      
      it 'should sort doc by sort_order' do
        @docs.last.should eql @doc_1
      end
    end

    context 'when sort_order is id ASC' do
      before do
        @docs = Doc.sort_by_params([['id ASC']])
      end

      it 'should sort doc by sort_order' do
        @docs.first.should eql @doc_1
      end

      it 'should sort doc by sort_order' do
        @docs.second.should eql @doc_2
      end
      
      it 'should sort doc by sort_order' do
        @docs.last.should eql @doc_3
      end
    end
  end
  
  describe 'self.order_by' do
    context 'when docs present' do
      context 'same_sourceid_denotations_count' do
        context 'when sourcedb = PubMed' do
          before do
            @count_1 = FactoryGirl.create(:doc, :sourceid => 1, :sourcedb => 'PubMed', :denotations_count => 1)
            @count_2 = FactoryGirl.create(:doc, :sourceid => 2, :sourcedb => 'PubMed', :denotations_count => 2)
            @count_3 = FactoryGirl.create(:doc, :sourceid => 3, :sourcedb => 'PubMed', :denotations_count => 3)
            @count_0 = FactoryGirl.create(:doc, :sourceid => 1, :sourcedb => 'PubMed', :denotations_count => 0)
            @docs = Doc.order_by(Doc.pmdocs, 'same_sourceid_denotations_count')
          end
          
          it 'docs.first should most same_sourceid_denotations_count' do
            @docs[0].should eql(@count_3)
          end
          
          it 'docs.first should second most same_sourceid_denotations_count' do
            @docs[1].should eql(@count_2)
          end
          
          it 'docs.first should second most same_sourceid_denotations_count' do
            @docs[2].should eql(@count_1)
          end
          
          it 'docs.first should least same_sourceid_denotations_count' do
            @docs.last.should eql(@count_0)
          end
        end
        
        context 'when sourcedb = PMC' do
          before do
            @count_1 = double(:same_sourceid_denotations_count => 1, :sourcedb => 'PMC')
            @count_2 = double(:same_sourceid_denotations_count => 2, :sourcedb => 'PMC')
            @count_3 = double(:same_sourceid_denotations_count => 3, :sourcedb => 'PMC')
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
      end
      
      context 'denotations_count' do
        before do
          @project = FactoryGirl.create(:project)
          @doc_denotations_3 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_3.id, :project_id => @project.id)
          3.times do
            FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_3)
          end
          @doc_denotations_2 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_2.id, :project_id => @project.id)
          2.times do
            FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_2)
          end
          @doc_denotations_1 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_1.id, :project_id => @project.id)
          FactoryGirl.create(:denotation, :project => @project, :doc => @doc_denotations_1)
          @doc_denotations_0 = FactoryGirl.create(:doc)
          @docs = Doc.order_by(Doc, 'denotations_count')
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
          @doc_3relations = FactoryGirl.create(:doc, :id => 5)
          3.times do
            denotation = FactoryGirl.create(:denotation, :project_id => 1, :doc => @doc_3relations)
            FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
          end
  
          @doc_2relations = FactoryGirl.create(:doc, :id => 4)
          2.times do
            denotation = FactoryGirl.create(:denotation, :project_id => 2, :doc => @doc_2relations)
            FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
          end
          
          @doc_1relations = FactoryGirl.create(:doc, :id => 3)
          denotation = FactoryGirl.create(:denotation, :project_id => 3, :doc => @doc_1relations)
          FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id)
          
          @doc_0relations = FactoryGirl.create(:doc, :id => 2)
          @docs = Doc.order_by(Doc, 'relations_count')
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
        context 'when sourcedb == PubMed' do
          before do
            @relations_count2 = FactoryGirl.create(:doc,  :sourceid => '12345', :subcatrels_count => 2, :sourcedb => 'PubMed')
            @relations_count3 = FactoryGirl.create(:doc,  :sourceid => '23456', :subcatrels_count => 3, :sourcedb => 'PubMed')
            @relations_count4 = FactoryGirl.create(:doc,  :sourceid => '34567', :subcatrels_count => 4, :sourcedb => 'PubMed')
            @relations_count0 = FactoryGirl.create(:doc,  :sourceid => '34567', :subcatrels_count => 0, :sourcedb => 'PubMed')
            @docs = Doc.order_by(Doc.pmdocs, 'same_sourceid_relations_count')
          end
          
          it 'doc which has 4 relations(same sourceid) should be docs[0]' do
            @docs[0].should eql(@relations_count4)
          end
          
          it 'doc which has 4 relations should be docs[1]' do
            @docs[1].should eql(@relations_count3)
          end
          
          it 'doc which has 3 relations should be docs[2]' do
            @docs[2].should eql(@relations_count2)
          end
          
          it 'doc which has 2 relations should be docs[3]' do
            @docs[3].should eql(@relations_count0)
          end
        end
        
        context 'when sourcedb == PMC' do
          before do
            @relations_count2 = FactoryGirl.create(:doc,  :sourceid => '12345', :subcatrels_count => 2, :sourcedb => 'PMC', :serial => 0)
            @relations_count3 = FactoryGirl.create(:doc,  :sourceid => '23456', :subcatrels_count => 3, :sourcedb => 'PMC', :serial => 0)
            @relations_count4 = FactoryGirl.create(:doc,  :sourceid => '34567', :subcatrels_count => 4, :sourcedb => 'PMC', :serial => 0)
            @relations_count0 = FactoryGirl.create(:doc,  :sourceid => '34567', :subcatrels_count => 0, :sourcedb => 'PMC', :serial => 0)
            @docs = Doc.order_by(Doc.pmcdocs, 'same_sourceid_relations_count')
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
      end
      
      context 'else' do
        before do
          @doc_111 = FactoryGirl.create(:doc, :sourceid => '111', :sourcedb => 'PubMed')
          @doc_1111 = FactoryGirl.create(:doc, :sourceid => '1111', :sourcedb => 'PubMed')
          @doc_1112 = FactoryGirl.create(:doc, :sourceid => '1112', :sourcedb => 'PubMed')
          @doc_1211 = FactoryGirl.create(:doc, :sourceid => '1211', :sourcedb => 'PubMed')
          @doc_11111 = FactoryGirl.create(:doc, :sourceid => '11111', :sourcedb => 'PubMed')
          @docs = Doc.order_by(Doc.pmdocs, nil)
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
    
    context 'when docs blank' do
      before do
        @docs = Doc.order_by(Doc.pmdocs, nil)
      end
      
      it 'should return blank' do
        @docs.should be_blank
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
      @doc.project_relations_count(nil).should eql(@project_relations_count)
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
      @doc.relations_count.should eql(@subcatrels_size)
    end
  end
  
  describe 'same_sourceid_denotations_count' do
    before do
      @sourceid_1234_doc_has_denotations_count = 3
      @sourceid_1234_doc_has_denotations_count.times do
        doc = FactoryGirl.create(:doc, :sourceid => '1234')
        FactoryGirl.create(:denotation, :project_id => 1, :doc => doc)
      end
      @sourceid_1234 = FactoryGirl.create(:doc, :sourceid => '1234')
      
      @sourceid_4567_doc_has_denotations_count = 2
      @sourceid_4567_doc_has_denotations_count.times do
        doc = FactoryGirl.create(:doc, :sourceid => '4567')
        FactoryGirl.create(:denotation, :project_id => 1, :doc => doc)
      end
      @sourceid_4567 = FactoryGirl.create(:doc, :sourceid => '4567')
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
      @same_sourceid_docs_count = 5
      @relations_size = 3
      # create documents
      @same_sourceid_docs_count.times do |i|
        id = i + 1
        doc = FactoryGirl.create(:doc, :id => id,  :sourceid => '123456')
        denotation = FactoryGirl.create(:denotation, :id => id, :project_id => 1, :doc => doc)
        # create relations
        @relations_size.times do |i|
          id = i + 1
          FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => 'Denotation', :obj_id => id)
        end
      end
      @doc = FactoryGirl.create(:doc,  :sourceid => '123456')
    end
    
    it 'should return sum of same sourceid docs subcatrels_count(= number of same sourceid docs and number of relations of those docs)' do
      @doc.same_sourceid_relations_count.should eql(@same_sourceid_docs_count * @relations_size)
    end
  end
  
  describe 'spans' do
    context 'when body not includes ascii text' do
      before do
        @body = '12345spansABCDE'
        @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
        @begin = 5
        @end = 10
      end
      
      context 'when encoding normal' do
        context 'when context_size is nil' do
          context 'when context is nil' do
            before do
              params = {:begin => @begin, :end => @end}
              @spans, @prev_text, @next_text = @doc.spans(params)
            end
            
            it 'should return body[begin...end] as spans' do
              @spans.should eql('spans')
            end
          end
          
          context 'when context_size is present' do
            context 'when begin of body' do
              before do
                @begin = 0
                @end = 5
                params = {:context_size => 5, :begin => @begin, :end => @end}
                @spans, @prev_text, @next_text = @doc.spans(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('')
              end
               
              it 'should set body[begin...end] as spans' do
                @spans.should eql('12345')
              end
              
              it 'should set next_text' do
                @next_text.should eql('spans')
              end
            end
            
            context 'when middle of body' do
              before do
                @begin = 5
                @end = 10
                params = {:context_size => 5, :begin => @begin, :end => @end}
                 @spans, @prev_text, @next_text = @doc.spans(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('12345')
              end
               
              it 'should set body[begin...end] as spans' do
                @spans.should eql('spans')
              end
              
              it 'should set next_text' do
                @next_text.should eql('ABCDE')
              end
            end
            
            context 'when end of body' do
              before do
                # '12345spansABCDE'
                @begin = 10
                @end = 15
                params = {:context_size => 5, :begin => @begin, :end => @end}
                @spans, @prev_text, @next_text = @doc.spans(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('spans')
              end
               
              it 'should set body[begin...end] as spans' do
                @spans.should eql('ABCDE')
              end
              
              it 'should set next_text' do
                @next_text.should eql('')
              end
            end

            context 'when format txt' do
              before do
                @begin = 5
                @end = 10
                params = {:format => 'txt', :context_size => 5, :begin => @begin, :end => @end}
                @spans, @prev_text, @next_text = @doc.spans(params)
              end
              
              it 'should set prev_text includes tab' do
                @prev_text.should eql("12345")
              end
               
              it 'should set body[begin...end] as spans includes tab' do
                @spans.should eql("spans")
              end
              
              it 'should set next_text' do
                @next_text.should eql('ABCDE')
              end
            end
          end
        end
      end

      context 'when encoding is ascii' do
        context 'when context_size is nil' do
          context 'when middle of body' do
            before do
              @begin = 5
              @end = 10
              params = {:encoding => 'ascii', :begin => @begin, :end => @end}
              @spans, @prev_text, @next_text = @doc.spans(params)
            end
            
            it 'should set body[begin...end] as spans' do
              @spans.should eql('spans')
            end
          end
        end
        
        context 'when context_size is present' do
          context 'when middle of body' do
            before do
              @begin = 5
              @end = 10
              params = {:encoding => 'ascii', :context_size => 5, :begin => @begin, :end => @end}
              @spans, @prev_text, @next_text = @doc.spans(params)
            end
            
            it 'should set prev_text' do
              @prev_text.should eql('12345')
            end
             
            it 'should set body[begin...end] as spans' do
              @spans.should eql('spans')
            end
            
            it 'should set next_text' do
              @next_text.should eql('ABCDE')
            end
          end
        end
      end
    end
    
    context 'when span includes ascii text' do
      before do
        @body = '12345Δ78901'
        @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
        @begin = 2
        @end = 7
      end
      
      context 'when encoding nil' do
        context 'when context_size present' do
          before do
            params = {:context_size => 10, :begin => @begin, :end => @end}
            @spans, @prev_text, @next_text = @doc.spans(params)
          end
          
          it 'should set get_ascii_text[begin...end] as spans' do
            @spans.should eql('345Δ7')
          end
          
          it 'should set prev_text' do
            @prev_text.should eql('12')
          end
          
          it 'should set next_text' do
            @next_text.should eql('8901')
          end
        end
      end
      
      context 'when encoding ascii' do
        context 'when context_size present' do
          before do
            params = {:encoding => 'ascii', :context_size => 10, :begin => @begin, :end => @end}
            @spans, @prev_text, @next_text = @doc.spans(params)
          end
          
          it 'should set get_ascii_text[begin...end] as spans' do
            @spans.should eql('345delta7')
          end
          
          it 'should set prev_text' do
            @prev_text.should eql('12')
          end
          
          it 'should set next_text' do
            @next_text.should eql('8901')
          end
        end
      end
    end
    
    context 'when body includes ascii text' do
      before do
        @body = '->Δ123Δ567Δ<-'
        @doc = FactoryGirl.create(:doc, :sourceid => '12345', :body => @body)
        @begin = 3
        @end = 10
      end
      
      context 'when encoding nil' do
        context 'when context_size present' do
          before do
            params = {:context_size => 3, :begin => @begin, :end => @end}
            @spans, @prev_text, @next_text = @doc.spans(params)
          end
          
          it 'should set get_ascii_text[begin...end] as spans' do
            @spans.should eql('123Δ567')
          end
          
          it 'should set prev_text' do
            @prev_text.should eql('->Δ')
          end
          
          it 'should set next_text' do
            @next_text.should eql('Δ<-')
          end
        end
      end
      
      context 'when encoding ascii' do
        context 'when context_size present' do
          before do
            params = {:encoding => 'ascii', :context_size => 3, :begin => @begin, :end => @end}
            @spans, @prev_text, @next_text = @doc.spans(params)
          end
          
          it 'should set get_ascii_text[begin...end] as spans' do
            @spans.should eql('123delta567')
          end
          
          it 'should set prev_text' do
            @prev_text.should eql('lta')
          end
          
          it 'should set next_text' do
            @next_text.should eql('del')
          end
        end
      end
    end    
  end

  describe 'text' do
    before do
      @doc = FactoryGirl.create(:doc)
      @spans = 'spans'
      @prev_text = 'prev_text'
      @next_text = 'next_text'
    end

    context 'when prev, next text is nil' do
      before do
        @doc.stub(:spans).and_return([@spans, nil, nil])
      end

      it 'should return spans text' do
        @doc.text(nil).should eql @spans 
      end
    end

    context 'when prev, next text prev' do
      before do
        @doc.stub(:spans).and_return([@spans, @prev_text, @next_text])
      end

      it 'should return joined prev_text spans next_text' do
        @doc.text(nil).should eql "#{@prev_text}#{@spans}#{@next_text}" 
      end
    end
  end

  describe 'to_csv' do
    before do
      @doc = FactoryGirl.create(:doc)
      @spans =['spans', 'prev', 'next']
      @doc.stub(:spans).and_return(@spans)
    end

    context 'when params[:context_size] not present' do
      before do
        @csv = @doc.to_csv({:context_size => true})
      end

      it 'should return csv data' do
        @csv.should eql("left\tfocus\tright\n#{@spans[1]}\t#{@spans[0]}\t#{@spans[2]}\n")
      end
    end

    context 'when params[:context_size] not present' do
      before do
        @csv = @doc.to_csv({})
      end

      it 'should return csv data' do
        @csv.should eql("focus\n#{@spans[0]}\n")
      end
    end
  end
  
  describe 'spans_highlight' do
    before do
      @begin = 5
      @end = 10
      @body = 'ABCDE12345ABCDE1234567890'

      @doc = FactoryGirl.create(:doc, body: @body)
      @spans_highlight = @doc.spans_highlight({begin: @begin, end: @end})
    end
    
    it 'should return prev, span, next text' do
      @spans_highlight.should eql("#{@doc.body[0...@begin]}<span class='highlight'>#{@doc.body[@begin...@end]}</span>#{@doc.body[@end..@doc.body.length]}")
    end
  end

  describe 'hdenotations' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_1 = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project_1.docs << @doc_1
      # doc and project match
      @doc_1_project_1_denotation_0_9 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 0, :end => 6)
      @doc_1_project_1_denotation_1_9 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 1, :end => 7)
      # doc match project not match
      @doc_1_project_2_denotation = FactoryGirl.create(:denotation, :project => @project_2, :doc => @doc_1, :begin => 2, :end => 8)
      @doc_2 = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '123', :serial => 1, :section => 'section', :body => 'doc body')
      # doc not match project match
      @doc_2_project_1_denotation = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_2, :begin => 3, :end => 9)
      @project_2.docs << @doc_2
    end
    
    context 'when options[:span] blank' do
      context 'when project.associate_projects blank' do
        before do
          @denotations = @doc_1.hdenotations(@project_1)  
        end
        
        it 'should return @doc.denotations project match' do
          @denotations[0].should eql(
          {
            :id => @doc_1_project_1_denotation_0_9.hid,
            :obj => @doc_1_project_1_denotation_0_9.obj,
            :span => {:begin => @doc_1_project_1_denotation_0_9.begin, :end => @doc_1_project_1_denotation_0_9.end}
          })
        end
        
        it 'should return @doc.denotations project match' do
          @denotations[1].should eql(
          {
            :id => @doc_1_project_1_denotation_1_9.hid,
            :obj => @doc_1_project_1_denotation_1_9.obj,
            :span => {:begin => @doc_1_project_1_denotation_1_9.begin, :end => @doc_1_project_1_denotation_1_9.end}
          })
        end
      end

      context 'when project.associate_projects present' do
        before do
          @project = FactoryGirl.create(:project)
          @project.associate_projects << @project_1
          @project.associate_projects << @project_2
          @project_denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc_1, :begin => 4, :end => 10)
          @denotations = @doc_1.hdenotations(@project)
        end
        
        it 'should return denotation belongs to doc, project and associate_proejct, and copied form associate_projects' do
          @denotations.size.should eql(7)
        end
        
        it 'should return @project.associate_projects.denotations project match' do
          @denotations[0].should eql(
          {
            :id => @doc_1_project_1_denotation_0_9.hid,
            :obj => @doc_1_project_1_denotation_0_9.obj,
            :span => {:begin => @doc_1_project_1_denotation_0_9.begin, :end => @doc_1_project_1_denotation_0_9.end}
          })
        end
        
        it 'should return @project.associate_projects.denotations project match' do
          @denotations[2].should eql(
          {
            :id => @doc_1_project_1_denotation_1_9.hid,
            :obj => @doc_1_project_1_denotation_1_9.obj,
            :span => {:begin => @doc_1_project_1_denotation_1_9.begin, :end => @doc_1_project_1_denotation_1_9.end}
          })
        end
        
        it 'should return @project.associate_projects.denotations project match' do
          @denotations[4].should eql(
          {
            :id => @doc_1_project_2_denotation.hid,
            :obj => @doc_1_project_2_denotation.obj,
            :span => {:begin => @doc_1_project_2_denotation.begin, :end => @doc_1_project_2_denotation.end}
          })
        end
        
        it 'should return @project.associate_projects.denotations project match' do
          @denotations[6].should eql(
          {
            :id => @project_denotation.hid,
            :obj => @project_denotation.obj,
            :span => {:begin => @project_denotation.begin, :end => @project_denotation.end}
          })
        end
      end
    end
    
    context 'when options[:span] present' do
      before do
        @denotation_within_span_1 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 40, :end => 49)
        @denotation_within_span_2 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 41, :end => 49)
        @denotations = @doc_1.hdenotations(@project_1, :spans => {:begin_pos => 40, :end_pos => 50})  
      end
      
      it 'should return @doc.denotations.within.spans' do
        @denotations[0].should eql(
        {:id => @denotation_within_span_1.hid,
        :obj => @denotation_within_span_1.obj,
        :span => {:begin => @denotation_within_span_1.begin, :end => @denotation_within_span_1.end}
        })
      end
      
      it 'should return @doc.denotations.within.spans' do
        @denotations[1].should eql(
        {:id => @denotation_within_span_2.hid,
        :obj => @denotation_within_span_2.obj,
        :span => {:begin => @denotation_within_span_2.begin, :end => @denotation_within_span_2.end}
        })
      end
    end
  end
  
  describe 'project_denotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project_1 = FactoryGirl.create(:project)
      @project_2 = FactoryGirl.create(:project)
      @denotation_1 = FactoryGirl.create(:denotation, :project_id => @project_1.id)
      @denotation_2 = FactoryGirl.create(:denotation, :project_id => @project_2.id)
      @doc.stub(:denotation).and_return([@denotation_1, @denotation_2])
      @hdenotaions = 'hdenotations'
      @doc.stub(:hdenotations) do |project|
        "project_id_#{ project.id }"
      end
      #and_return(@hdenotaions)
      @project_denotaions = @doc.project_denotations
    end
    
    it 'should return project' do
      @project_denotaions[0][:project].should eql(@project_1)
    end
    
    it 'should return denotations' do
      @project_denotaions[0][:denotations].should eql("project_id_#{ @project_1.id }")
    end
    
    it 'should return project' do
      @project_denotaions[1][:project].should eql(@project_2)
    end
    
    it 'should return denotations' do
      @project_denotaions[1][:denotations].should eql("project_id_#{ @project_2.id }")
    end
  end
  
  describe 'hrelations' do
    before do
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when options[:spans] present' do
      before do
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @relation_1 = FactoryGirl.create(:relation, :hid => 'H1', :subj_id => @denotation_1.id, :obj_id => @denotation_1.id, :obj_type => 'Denotation', :subj_type => 'Denotation')
        @relation_2 = FactoryGirl.create(:relation, :hid => 'H2', :subj_id => @denotation_1.id, :obj_id => @denotation_1.id, :obj_type => 'Denotation', :subj_type => 'Denotation')
      end
      
      context 'when project blank' do
        before do
          @hrelations  = @doc.hrelations(nil, {:spans => {:begin_pos => 1, :end_pos => 5}} )
        end

        it 'should return doc.denotations subjrels && objrels' do
          @hrelations.should eql([
              {:id => @relation_1.hid, :pred => @relation_1.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid}, 
              {:id => @relation_2.hid, :pred => @relation_2.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid} 
          ])
        end
      end
      
      context 'when project present' do
        before do
          @project = FactoryGirl.create(:project)
          @project.stub_chain(:relations, :where).and_return([@relation_2])
          @hrelations  = @doc.hrelations(@project, {:spans => {:begin_pos => 1, :end_pos => 5}} )
        end

        it 'should return project.relations' do
          @hrelations.should eql([
              {:id => @relation_2.hid, :pred => @relation_2.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid} 
          ])
        end
      end
    end
    
    context 'when options blank' do
      before do
        @project_1 = FactoryGirl.create(:project)
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @instance_1 = FactoryGirl.create(:instance, :obj => @denotation_1)
        @relation_1 = FactoryGirl.create(:subcatrel, :obj => @denotation_1, :project => @project_1)
        @relation_2 = FactoryGirl.create(:subinsrel, :obj => @instance_1, :project => @project_1)

        @project_2 = FactoryGirl.create(:project)
        @denotation_2 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @instance_2 = FactoryGirl.create(:instance, :obj => @denotation_2)
        @relation_3 = FactoryGirl.create(:subcatrel, :obj => @denotation_2, :project => @project_2)
        @relation_4 = FactoryGirl.create(:subinsrel, :obj => @instance_2, :project => @project_2)
      end
      
      context 'when project.associate_projects blank' do
        before do
          @hrelations  = @doc.hrelations(@project_1)
        end
        
        it 'should return doc.subcatrels and subinsresl' do
          @hrelations.should eql([
              {:id => @relation_1.hid, :pred => @relation_1.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid}, 
              # {:id => @relation_2.hid, :pred => @relation_2.pred, :subj => @instance_1.hid, :obj => @instance_1.hid}
          ])
        end
      end
      
      context 'when project.associate_projects present' do
        before do
          @project = FactoryGirl.create(:project)
          @project.associate_projects << @project_1
          @project.associate_projects << @project_2
          @hrelations  = @doc.hrelations(@project)
        end
        
        it 'should return doc.subcatrels and subinsresl' do
          @hrelations.should eql([
              {:id => @relation_1.hid, :pred => @relation_1.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid}, 
              {:id => @relation_3.hid, :pred => @relation_3.pred, :subj => @denotation_2.hid, :obj => @denotation_2.hid} 
          ])
        end
      end
    end
  end
  
  describe 'spans_projects' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation_project_1 = FactoryGirl.create(:project)
      @denotation_project_2 = FactoryGirl.create(:project)
      @not_denotation_project = FactoryGirl.create(:project)
      @denotation_1 = FactoryGirl.create(:denotation, :project => @denotation_project_1, :doc => @doc)
      @denotation_2 = FactoryGirl.create(:denotation, :project => @denotation_project_2, :doc => @doc)
      @denotation_3 = FactoryGirl.create(:denotation, :project_id => 1000, :doc => @doc)
      @denotations = double(:denotations)
      @doc.stub(:denotations).and_return(@denotations)
      @denotations.stub(:within_spans).and_return([@denotation_1, @denotation_2, @denotation_3])
      @projects = @doc.spans_projects({:begin => nil, :end => nil})
    end
    
    it 'should return projects which has doc.denotations as denotations' do
      @projects.should =~ [@denotation_project_1, @denotation_project_2]
    end
  end
  
  describe 'hmodifications' do
    before do
      @doc = FactoryGirl.create(:doc)
    end
      
    context 'when options[:spans] present' do
      before do
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @instance_1 = FactoryGirl.create(:instance, :obj => @denotation_1, :project_id => 1)
        @modification_1 = FactoryGirl.create(:modification, :hid => 'HID', :pred => 'PRED', :obj_type => 'Denotation', :obj => @denotation_1)
        @hmodifications = @doc.hmodifications(@project,  {:spans => {:begin_pos => 1, :end_pos => 5}})
      end
      
      it 'should return denotations.within_spans.modifications' do
        @hmodifications.should eql([{:id => @modification_1.hid, :pred => @modification_1.pred, :obj => @denotation_1.hid}])
      end
    end
    
    context 'when options[:spans] blank' do
      before do
        @project_1 = FactoryGirl.create(:project)
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc)
        # @instance_1 = FactoryGirl.create(:instance, :obj => @denotation_1, :project => @project_1)
        @modification_1 = FactoryGirl.create(:modification, :hid => 'M1', :obj => @denotation_1, :project => @project_1)
        @relation_1 = FactoryGirl.create(:subcatrel, :hid => 'r1', :obj => @denotation_1, :project => @project_1)
        @relation_2 = FactoryGirl.create(:subinsrel, :hid => 'r2', :obj => @denotation_1, :project => @project_1)
        @modification_2 = FactoryGirl.create(:modification, :hid => 'M2', :obj => @relation_1, :obj_type => @relation_1.class.to_s, :project => @project_1)
        @modification_3 = FactoryGirl.create(:modification, :hid => 'M3', :obj => @relation_2, :obj_type => @relation_2.class.to_s, :project => @project_1)

        @project_2 = FactoryGirl.create(:project)
        @denotation_2 = FactoryGirl.create(:denotation, :doc => @doc)
        # @instance_2 = FactoryGirl.create(:instance, :obj => @denotation_2, :project => @project_2)
        @modification_4 = FactoryGirl.create(:modification, :hid => 'M4', :obj => @denotation_2, :project => @project_2)
        @relation_3 = FactoryGirl.create(:subcatrel, :hid => 'r3', :obj => @denotation_2, :project => @project_2)
        @relation_4 = FactoryGirl.create(:subinsrel, :hid => 'r4', :obj => @denotation_2, :project => @project_2)
        @modification_5 = FactoryGirl.create(:modification, :hid => 'M5', :obj => @relation_3, :obj_type => @relation_3.class.to_s, :project => @project_2)
        @modification_6 = FactoryGirl.create(:modification, :hid => 'M6', :obj => @relation_4, :obj_type => @relation_4.class.to_s, :project => @project_2)
        @hmodifications = @doc.hmodifications(@project_1) 
      end
      
      it 'should return self.catmods, subcatrelmods and subinsrelmods where project_id = project.id' do
        @hmodifications.should eql([
          {:id => @modification_1.hid, :pred => @modification_1.pred, :obj => @denotation_1.hid}, 
          {:id => @modification_2.hid, :pred => @modification_2.pred, :obj => @relation_1.hid} 
        ])
      end
    end
  end
  
  describe 'sql_find' do
    before do
      @current_user = FactoryGirl.create(:user)
      @accessible_doc = FactoryGirl.create(:doc)
      @project_doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project)
      # stub scope and return all Doc
      @accessible_projects = Doc.where(:id => @accessible_doc.id)
      Doc.stub(:accessible_projects).and_return(@accessible_projects)
      @project_docs = Doc.where(:id => @project_doc.id)
      Doc.stub(:projects_docs).and_return(@project_docs)
    end
    
    context 'when params[:sql] present' do
      context 'when current_user present' do
        before do
          @params = {:sql => 'select * from docs;'}
        end
        
        context 'when results present' do
          context 'when project present' do
            before do
              @docs = Doc.sql_find(@params, @current_user, @project)
            end
            
            it 'should return sql result refined by scope project_docs' do
              @docs.should =~ @project_docs
            end
          end
  
          context 'when project blank' do
            before do
              @docs = Doc.sql_find(@params, @current_user, nil)
            end
            
            it 'should return sql result refined by scope accessible_projects' do
              @docs.should =~ @accessible_projects
            end
          end
        end
        
        context 'when results blank' do
          it 'should return nil' do
            Doc.sql_find({:sql => 'select * from docs where id = 1000'}, @current_user, @project).should be_nil
          end
        end
      end

      context 'when current_user nil' do
        before do
          @params = {:sql => 'select * from docs;'}
        end
        
        context 'when results present' do
          context 'when project present' do
            before do
              @docs = Doc.sql_find(@params, nil, @project)
            end
            
            it 'should return sql result refined by scope project_docs' do
              @docs.should =~ @project_docs
            end
          end
  
          context 'when project blank' do
            before do
              @docs = Doc.sql_find(@params, nil, nil)
            end
            
            it 'should return sql result refined by scope accessible_projects' do
              @docs.should =~ @accessible_projects
            end
          end
        end
        
        context 'when results blank' do
          it 'should return nil' do
            Doc.sql_find({:sql => 'select * from docs where id = 1000'}, nil, @project).should be_nil
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
  
  describe 'updatable_for?' do
    before do
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when user.root is true' do
      before do
        @user = FactoryGirl.create(:user, root: true)
      end

      it 'should return true' do
        @doc.updatable_for?(@user).should be_true
      end
    end

    context 'when doc.projects present' do 
      context 'when doc.projects present' do 
        before do
          @project_user = FactoryGirl.create(:user)
          @project = FactoryGirl.create(:project, :user => @project_user)
          @associate_maintainer_user_1 = FactoryGirl.create(:user)
          @project.associate_maintainers.create({:user_id => @associate_maintainer_user_1.id})
          @project.docs << @doc
        end
        
        context 'when current_user is doc.projects.user' do
          it 'should return true' do
            @doc.updatable_for?(@project_user).should be_true
          end
        end
        
        context 'when current_user is project.associate_maintainer.user' do
          it 'should return true' do
            @doc.updatable_for?(@associate_maintainer_user_1).should be_true
          end
        end
        
        context 'when current_user is not project.user nor project.associate_maintainer.user' do
          it 'should return false' do
            @doc.updatable_for?(FactoryGirl.create(:user)).should be_false
          end
        end
        
        context 'when current_user is blank' do
          it 'should return false' do
            @doc.updatable_for?(nil).should be_false
          end
        end
      end
    end
  end
  
  describe 'generate_divs' do
    before do
      @hash_1 = {:heading => 'HEAD1', :body => 'DIV BODY1'}
      @hash_2 = {:heading => 'HEAD2', :body => 'DIV BODY2'}
      @divs_hash = [@hash_1, @hash_2]
      @attributes = {
        :source_url => 'http://source.url',
        :sourcedb => 'sourcedb',
        :sourceid => 'sourceid'
      }
      @divs = Doc.create_divs(@divs_hash, @attributes)
    end
    
    it 'should create divs.body from divs_hash[:body]' do
      @divs.collect{|div| div.body}.should =~ [@hash_1[:body], @hash_2[:body]]
    end
    
    it 'should create divs.section from divs_hash[:heading]' do
      @divs.collect{|div| div.section}.should =~ [@hash_1[:heading], @hash_2[:heading]]
    end
    
    it 'should create divs.source_url from attributes[:source_url]' do
      @divs.collect{|div| div.source}.uniq.should =~ [@attributes[:source_url]]
    end
    
    it 'should create divs.sourcedb from attributes[:sourcedb]' do
      @divs.collect{|div| div.sourcedb}.uniq.should =~ [@attributes[:sourcedb]]
    end
    
    it 'should create divs.sourceid from attributes[:sourceid]' do
      @divs.collect{|div| div.sourceid}.uniq.should =~ [@attributes[:sourceid]]
    end
  end
  
  describe 'has_divs?' do
    before do
      @sourcedb = 'sourcedb'
      @sourceid = 123456789
      @doc = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid)  
    end
    
    context 'when same sourcedb and sourceid doc blank' do
      it 'shoud return false' do
        @doc.has_divs?.should be_false
      end
    end
    
    context 'when same sourcedb and sourceid doc present' do
      before do
        FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid)  
      end
      
      it 'shoud return true' do
        @doc.has_divs?.should be_true
      end
    end
  end
   
  describe 'decrement_docs_counter' do
    before do
      @project_pmdocs_count = 1
      @project_pmcdocs_count = 2
      @project =             FactoryGirl.create(:project, :pmdocs_count => @project_pmdocs_count, :pmcdocs_count => @project_pmcdocs_count)
      @associate_project_1 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1_pmdocs_count = 3
      @i = 1
      @associate_project_1_pmdocs_count.times do
        @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i)
        @i += 1 
      end
      @associate_project_1_pmcdocs_count = 3
      @div = FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i)
      @i += 1 
      @associate_project_1_pmcdocs_count.times do
        @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
        @i += 1 
      end     
      # @associate_project_1.pmcdocs_count 3 => 4
      @associate_project_1.docs << @div
      @associate_project_1.reload
      
      @associate_project_2 = FactoryGirl.create(:project, :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 4
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i) 
        @i += 1 
      end
      @associate_project_2_pmcdocs_count = 6
      @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i)
      @i += 1 
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0, :sourceid => @i) 
        @i += 1 
      end     
      # @associate_project_2.pmdocs_count 4 => 5
      @associate_project_2.docs << @doc
      @associate_project_2.reload
      @project.associate_projects << @associate_project_1
      @project.associate_projects << @associate_project_2
      @project.reload
    end
    
    describe 'before destroy' do
      it 'associate_project_1 should incremented pmcdocs counter' do
        @associate_project_1.pmcdocs_count.should eql(4)
      end

      it 'associate_project_2 should incremented pmdocs counter' do
        @associate_project_2.pmdocs_count.should eql(5)
      end
      
      it 'project.pmdocs_count should equal sum of associate proejct pmdocs count and copied pmdocs and self.pmdocs_count' do
        @project.pmdocs_count.should eql((@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2  + 2 + @project_pmdocs_count)
      end

      it 'project.pmcdocs_count should equal sum of associate proejct pmdcocs count and copied pmdocs and self.pmdocs_count' do
        @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) * 2 + 2 + @project_pmcdocs_count)
      end
    end
    
    context 'when PMC docs' do
      before do
        @project.reload
        @div.destroy
      end
      
      it 'should decrement doc.projects pmcdocs_count' do
        @project.reload #
        @project.pmcdocs_count.should eql(((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) *2 + 2 + @project_pmcdocs_count) -2 )
        @project.pmdocs_count.should eql((@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2  + 2 + @project_pmdocs_count)
      end
              
      it 'should incremant only associate project.pmdcocs_count' do
        @associate_project_1.reload
        @associate_project_1.pmcdocs_count.should eql(3)
        @associate_project_1.pmdocs_count.should eql(3)
      end
              
      it 'should incremant only associate project.pmdcocs_count' do
        @associate_project_2.reload
        @associate_project_2.pmdocs_count.should eql(5)
        @associate_project_2.pmcdocs_count.should eql(6)
      end
    end
    
    context 'when PubMed docs' do
      before do
        @doc.destroy
      end
      
      it 'should decrement doc.projects pmdocs_count' do
        @project.reload
        @project.pmdocs_count.should eql(((@associate_project_1_pmdocs_count + @associate_project_2_pmdocs_count) * 2  + 2 + @project_pmdocs_count) -2 )
        @project.pmcdocs_count.should eql((@associate_project_1_pmcdocs_count + @associate_project_2_pmcdocs_count) *2 + 2 + @project_pmcdocs_count)
      end
              
      it 'should incremant only associate project.pmdcocs_count' do
        @associate_project_1.reload
        @associate_project_1.pmdocs_count.should eql(3)
        @associate_project_1.pmcdocs_count.should eql(4)
      end
              
      it 'should incremant only associate project.pmdcocs_count' do
        @associate_project_2.reload
        @associate_project_2.pmdocs_count.should eql(4)
        @associate_project_2.pmcdocs_count.should eql(6)
      end
    end
  end
end
