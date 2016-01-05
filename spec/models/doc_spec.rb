# encoding: utf-8
require 'spec_helper'

describe Doc do
  describe 'after_save' do
    it 'should call expire_page_cache' do
      @doc = FactoryGirl.build(:doc)
      @doc.should_receive(:expire_page_cache)
      @doc.save
    end

    context 'when after_destroy' do
    end
  end

  describe 'before_destroy' do
    let(:doc) { FactoryGirl.create(:doc) }

    it 'should call decrement_docs_counter' do
      expect(doc).to receive(:decrement_docs_counter)
      doc.destroy
    end
  end

  describe 'after_destroy' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:action_controller_base) { double(:action_controller_base) }

    before do
      ActionController::Base.stub(:new).and_return(action_controller_base)
      action_controller_base.stub(:expire_fragment).and_return(nil)
    end

    it 'should call expire_page_cache' do
      expect(doc).to receive(:expire_page_cache)
      doc.destroy
    end

    it 'should call expire_fragment' do
      expect(action_controller_base).to receive(:expire_fragment)
      doc.destroy
    end
  end

  describe 'has_many denotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @doc_denotation = FactoryGirl.create(:denotation, doc: @doc)
      FactoryGirl.create(:annotations_project, project_id: 1, annotation: @doc_denotation)
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
      @denotation = FactoryGirl.create(:denotation, doc_id: @doc.id)
      @subj = FactoryGirl.create(:denotation, doc_id: @doc.id)
      @subcatrel = FactoryGirl.create(:subcatrel, :subj_id => @subj.id, :obj_id => @denotation.id)

      @denotation.reload
      @subj.reload
      @subcatrel.reload
      @doc.reload
    end
    
    it 'doc.denotations should include related denotation' do
      @doc.denotations.should include(@denotation)
      @doc.denotations.should include(@subj)
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
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subinsrel = FactoryGirl.create(:relation,
        :subj_id => @instance.id,
        :subj_type => @instance.class.to_s,
        :obj_id => 20,
        :project => @project
      ) 
    end
  end
  
  describe 'has_many subcatrelmods' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, doc: @doc)
      @subj = FactoryGirl.create(:denotation, doc: @doc)
      @subcatrel = FactoryGirl.create(:subcatrel, subj_id: @subj.id, obj_id: @denotation.id)
      @subcatrelmod = FactoryGirl.create(:modification, obj: @subcatrel, obj_type: 'Annotation')
    end
    
    it 'doc.subcatrelmods should present' do
      @doc.subcatrels.should be_present
    end
    
    it 'doc.subcatrelmods should inclde modification through subcatrels' do
      (@doc.subcatrelmods - [@subcatrelmod]).should be_blank
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

  describe 'validates_uniqueness_of sourcedb, sourceid and serial' do
    before do
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when same sourcedb, sourceid and serial present' do
      before do
        @new_doc = FactoryGirl.build(:doc, serial: @doc.serial)
      end

      it 'should raise validation error' do
        @new_doc.valid?
        @new_doc.errors.messages[:serial].should eql([I18n.t('errors.messages.taken')])
      end
    end
    
    context 'when same sourcedb, sourceid and another serial present' do
      before do
        @new_doc = FactoryGirl.build(:doc)
      end

      it 'should be valid ' do
        @new_doc.valid?.should be_true
      end
    end
  end
  
  describe 'scope pmdocs' do
    before do
      @pmdocs_count = 3
      @pmdocs_count.times do |time|
        FactoryGirl.create(:doc, :sourcedb => 'PubMed', serial: time)
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

  describe 'scope pmcdocs' do
    before do
      @pmcdocs_count = 3
      @pmcdocs_count.times do |time|
        FactoryGirl.create(:doc, :sourcedb => 'PMC', sourceid: time.to_s, serial: 0)
      end
      @not_pmcdoc = FactoryGirl.create(:doc, :sourcedb => 'PubMed')
      @serial_1 = FactoryGirl.create(:doc, :sourcedb => 'PMC')
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

  describe 'scope project_name' do
    before do
      @project_1 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :name => 'project_1')
      @doc_1 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      @doc_2 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_2.id)
      @project_2 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :name => 'project_2')
      @doc_3 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_3.id)
      @project_name = Doc.project_name(@project_1.name)
    end

    it '' do
      @project_name.should =~ [@doc_1, @doc_2]
    end
  end

  describe 'scope relations_count' do
    # has 1 relations
    let!(:doc_1) { FactoryGirl.create(:doc) } 
    let!(:denotationa_doc_1_1) { FactoryGirl.create(:denotation, doc_id: doc_1.id) }
    let!(:relation_denotation_1) { FactoryGirl.create(:relation, subj_id: denotationa_doc_1_1.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }

    # has 3 relations
    let!(:doc_2) { FactoryGirl.create(:doc) } 
    let!(:denotationa_doc_2_1) { FactoryGirl.create(:denotation, doc_id: doc_2.id) }
    let!(:relation_denotation_2) { FactoryGirl.create(:relation, subj_id: denotationa_doc_2_1.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }
    let!(:denotationa_doc_2_2) { FactoryGirl.create(:denotation, doc_id: doc_2.id) }
    let!(:relation_denotation_3) { FactoryGirl.create(:relation, subj_id: denotationa_doc_2_2.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }
    let!(:denotationa_doc_2_3) { FactoryGirl.create(:denotation, doc_id: doc_2.id) }
    let!(:relation_denotation_4) { FactoryGirl.create(:relation, subj_id: denotationa_doc_2_3.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }

    # has 4 relations
    let!(:doc_3) { FactoryGirl.create(:doc) } 
    let!(:denotationa_doc_3_1) { FactoryGirl.create(:denotation, doc_id: doc_3.id) }
    let!(:relation_denotation_5) { FactoryGirl.create(:relation, subj_id: denotationa_doc_3_1.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }
    let!(:denotationa_doc_3_2) { FactoryGirl.create(:denotation, doc_id: doc_3.id) }
    let!(:relation_denotation_6) { FactoryGirl.create(:relation, subj_id: denotationa_doc_3_2.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }
    let!(:relation_denotation_7) { FactoryGirl.create(:relation, subj_id: denotationa_doc_3_2.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }
    let!(:relation_denotation_8) { FactoryGirl.create(:relation, subj_id: denotationa_doc_3_2.id, subj_type: 'Annotation', obj: denotationa_doc_1_1) }

    # has 0 relations
    let!(:doc_4) { FactoryGirl.create(:doc) } 

    it 'should order Docs by count of relations' do
      expect( Doc.relations_count.first ).to eql(doc_3)
      expect( Doc.relations_count.second ).to eql(doc_2)
      expect( Doc.relations_count.last ).to eql(doc_4)
    end
  end

  describe 'scope projects_docs' do
    before do
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_1 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_2 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_2.id)
      @project_3 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_3 = FactoryGirl.create(:doc)
      FactoryGirl.create(:docs_project, :project_id => @project_3.id, :doc_id => @doc_3.id)
      @projects_docs = Doc.projects_docs([@project_1.id, @project_2.id]) 
    end

    it 'should return docs belongs to projects' do
      @projects_docs.should =~ [@doc_1, @doc_2]
    end
  end

  describe 'scope accessible_projects' do
    let!(:user) { FactoryGirl.create(:user) } 
    let!(:current_user) { FactoryGirl.create(:user) } 
    let!(:doc_1) { FactoryGirl.create(:doc) } 
    let!(:doc_2) { FactoryGirl.create(:doc) } 
    let!(:doc_3) { FactoryGirl.create(:doc) } 
    let!(:doc_4) { FactoryGirl.create(:doc) } 
    let!(:project_accessibility_0_user) { FactoryGirl.create(:project, accessibility: 0, user: user) } 
    let!(:docs_project_1) { FactoryGirl.create(:docs_project, doc_id: doc_1.id, project_id: project_accessibility_0_user.id) } 
    let!(:project_accessibility_1_user) { FactoryGirl.create(:project, accessibility: 1, user: user) } 
    let!(:docs_project_2) { FactoryGirl.create(:docs_project, doc_id: doc_2.id, project_id: project_accessibility_1_user.id) } 
    let!(:project_accessibility_0_currrent_user) { FactoryGirl.create(:project, accessibility: 0, user: current_user) } 
    let!(:docs_project_3) { FactoryGirl.create(:docs_project, doc_id: doc_3.id, project_id: project_accessibility_0_currrent_user.id) } 
    let!(:project_accessibility_1_currrent_user) { FactoryGirl.create(:project, accessibility: 1, user: current_user) } 
    let!(:docs_project_4) { FactoryGirl.create(:docs_project, doc_id: doc_4.id, project_id: project_accessibility_1_currrent_user.id) } 

    it 'should include project.accessibility == 1 OR user_id == current_user.id' do
      expect( Doc.accessible_projects(current_user) ).to include(doc_2)
      expect( Doc.accessible_projects(current_user) ).to include(doc_3)
      expect( Doc.accessible_projects(current_user) ).to include(doc_4)
    end
  end

  describe 'scope sql' do
    let!(:doc_1) { FactoryGirl.create(:doc) } 
    let!(:doc_2) { FactoryGirl.create(:doc) } 
    let!(:doc_3) { FactoryGirl.create(:doc) } 

    it 'should return docs id included in array and order by id asc' do
      expect( Doc.sql([doc_1.id, doc_2.id, doc_3.id]).first ).to eql(doc_1)
      expect( Doc.sql([doc_1.id, doc_2.id, doc_3.id]).last ).to eql(doc_3)
    end
  end

  describe 'scope source_db_id' do
    before do
      @doc_sourcedb_uniq = FactoryGirl.create(:doc, :sourcedb => 'Uniq1', :sourceid => '11')
      @doc_sourceid_uniq_1 = FactoryGirl.create(:doc, :sourcedb => 'Uniq2', :sourceid => '10')
      @doc_sourceid_uniq_2 = FactoryGirl.create(:doc, :sourcedb => 'Uniq2', :sourceid => '12')
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
        @docs.first.sourcedb.should eql (@doc_sourceid_uniq_1.sourcedb)
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

  describe 'same_sourcedb_sourceid' do
    let!(:doc_sourcedb_pmc_sourceid_1_1) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '1') } 
    let!(:doc_sourcedb_pmc_sourceid_1_2) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '1') } 
    let!(:doc_sourcedb_pmc_sourceid_2_1) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '2') } 
    let!(:doc_sourcedb_pdc_sourceid_2_1) { FactoryGirl.create(:doc, sourcedb: 'PDC', sourceid: '1') } 

    it 'should return same sourcedb and sourceid docs' do
      expect( Doc.same_sourcedb_sourceid('PMC', '1') ).to match_array([ doc_sourcedb_pmc_sourceid_1_1, doc_sourcedb_pmc_sourceid_1_2 ])
    end
  end

  describe 'sourcedbs' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      # create docs belongs to project
      @project_doc_1 = FactoryGirl.create(:doc, :sourcedb => "sourcedb1")
      @project_doc_2 = FactoryGirl.create(:doc, :sourcedb => "sourcedb2")
      # create docs not belongs to project
      2.times do
        FactoryGirl.create(:doc, :sourcedb => 'sdb')
      end
      @docs = Doc.sourcedbs   
    end

    it 'should not include sourcedb is nil or blank' do
      @docs.select{|doc| doc.sourcedb == nil || doc.sourcedb == ''}.should be_blank
    end
  end

  describe 'user_source_db' do
    before do
      @username = 'username'
      @similar_username = 'username1'
      @doc_username_1 = FactoryGirl.create(:doc, sourcedb: "AA1#{Doc::UserSourcedbSeparator}#{@username}")
      @doc_username_2 = FactoryGirl.create(:doc, sourcedb: "AA2#{Doc::UserSourcedbSeparator}#{@username}")
      @doc_similar_username_1 = FactoryGirl.create(:doc, sourcedb: "AA1#{Doc::UserSourcedbSeparator}#{@similar_username}")
      @doc_similar_username_2 = FactoryGirl.create(:doc, sourcedb: "AA2#{Doc::UserSourcedbSeparator}#{@similar_username}")
      @doc_similar_username_3 = FactoryGirl.create(:doc, sourcedb: "#{@username}#{Doc::UserSourcedbSeparator}#{@similar_username}")
      @doc_similar_username_4 = FactoryGirl.create(:doc, sourcedb: @username)
    end

    it 'should return docs include username after separator' do
      Doc.user_source_db(@username).should =~ [@doc_username_1, @doc_username_2]
    end
  end

  describe 'sort_by_params' do
    before do
      @doc_1 = FactoryGirl.create(:doc, body: 'doc_1')
      @doc_2 = FactoryGirl.create(:doc, body: 'doc_2')
      @doc_3 = FactoryGirl.create(:doc, body: 'doc_3')
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
            @count_1 = FactoryGirl.create(:doc, :sourceid => 1.to_s, :sourcedb => 'PubMed', :denotations_count => 1)
            @count_2 = FactoryGirl.create(:doc, :sourceid => 2.to_s, :sourcedb => 'PubMed', :denotations_count => 2)
            @count_3 = FactoryGirl.create(:doc, :sourceid => 3.to_s, :sourcedb => 'PubMed', :denotations_count => 3)
            @count_0 = FactoryGirl.create(:doc, :sourceid => 1.to_s, :sourcedb => 'PubMed', :denotations_count => 0)
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
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @doc_denotations_3 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_3.id, :project_id => @project.id)
          3.times do
            denotation = FactoryGirl.create(:denotation, :doc => @doc_denotations_3)
            FactoryGirl.create(:annotations_project, project_id: @project.id, annotation_id: denotation.id)
          end
          @doc_denotations_2 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_2.id, :project_id => @project.id)
          2.times do
            denotation = FactoryGirl.create(:denotation, :doc => @doc_denotations_2)
            FactoryGirl.create(:annotations_project, project_id: @project.id, annotation_id: denotation.id)
          end
          @doc_denotations_1 = FactoryGirl.create(:doc)
          FactoryGirl.create(:docs_project, :doc_id => @doc_denotations_1.id, :project_id => @project.id)
          denotation = FactoryGirl.create(:denotation, :doc => @doc_denotations_1)
          FactoryGirl.create(:annotations_project, project_id: @project.id, annotation_id: denotation.id)
          @doc_denotations_0 = FactoryGirl.create(:doc)
          @docs = Doc.order_by(Doc.all, 'get_denotations_count')
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
        let (:relations_count) { double(:relations_count) }
        let (:docs) { Doc }

        before do
          Doc.stub(:relations_count).and_return(relations_count)
        end

        it 'should requturn docs.relations_count' do
          expect( Doc.order_by(docs, 'relations_count') ).to eql(relations_count)
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
            @relations_count0 = FactoryGirl.create(:doc,  :sourceid => '34567', :subcatrels_count => 0, :sourcedb => 'PMC', :serial => 0)
            @docs = Doc.order_by(Doc.pmcdocs, 'same_sourceid_relations_count')
          end
          
          it 'doc which has 3 relations(same sourceid) should be docs[0]' do
            @docs[0].should eql(@relations_count3)
          end
          
          it 'doc which has 2 relations should be docs[1]' do
            @docs[1].should eql(@relations_count2)
          end
          
          it 'doc which has 0 relations should be docs[2]' do
            @docs[2].should eql(@relations_count0)
          end
          
          # it 'doc which has 2 relations should be docs[3]' do
          #   @docs[3].should eql(@relations_count2)
          # end
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
        denotation = FactoryGirl.create(:denotation, doc: doc)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: denotation.id)
      end
      @sourceid_1234 = FactoryGirl.create(:doc, :sourceid => '1234')
      
      @sourceid_4567_doc_has_denotations_count = 2
      @sourceid_4567_doc_has_denotations_count.times do
        doc = FactoryGirl.create(:doc, :sourceid => '4567')
        denotation = FactoryGirl.create(:denotation, doc: doc)
        FactoryGirl.create(:annotations_project, project_id: 1, annotation_id: denotation.id)
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
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @same_sourceid_docs_count.times do |i|
        id = i + 1
        doc = FactoryGirl.create(:doc,  :sourceid => '123456')
        denotation = FactoryGirl.create(:denotation, :doc => doc)
        FactoryGirl.create(:annotations_project, project: @project, annotation: denotation)
        # create relations
        @relations_size.times do |i|
          id = i + 1
          relation = FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => 'Denotation', :obj_id => id)
          FactoryGirl.create(:annotations_project, project: @project, annotation: relation)
        end
      end
      @doc = FactoryGirl.create(:doc,  :sourceid => '123456')
    end
    
    it 'should return sum of same sourceid docs subcatrels_count(= number of same sourceid docs and number of relations of those docs)' do
      @doc.same_sourceid_relations_count.should eql(@same_sourceid_docs_count * @relations_size)
    end
  end
  
  describe 'span' do
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
              @prev_text, @span, @next_text = @doc.span(params)
            end
            
            it 'should return body[begin...end] as spans' do
              @span.should eql('spans')
            end
          end
          
          context 'when context_size is present' do
            context 'when begin of body' do
              before do
                @begin = 0
                @end = 5
                params = {:context_size => 5, :begin => @begin, :end => @end}
                @prev_text, @span, @next_text = @doc.span(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('')
              end
               
              it 'should set body[begin...end] as span' do
                @span.should eql('12345')
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
                 @prev_text, @span, @next_text = @doc.span(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('12345')
              end
               
              it 'should set body[begin...end] as span' do
                @span.should eql('spans')
              end
              
              it 'should set next_text' do
                @next_text.should eql('ABCDE')
              end
            end
            
            context 'when end of body' do
              before do
                # '12345spanABCDE'
                @begin = 10
                @end = 15
                params = {:context_size => 5, :begin => @begin, :end => @end}
                @prev_text, @span, @next_text = @doc.span(params)
              end
              
              it 'should set prev_text' do
                @prev_text.should eql('spans')
              end
               
              it 'should set body[begin...end] as span' do
                @span.should eql('ABCDE')
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
                @prev_text, @span, @next_text = @doc.span(params)
              end
              
              it 'should set prev_text includes tab' do
                @prev_text.should eql("12345")
              end
               
              it 'should set body[begin...end] as span includes tab' do
                @span.should eql("spans")
              end
              
              it 'should set next_text' do
                @next_text.should eql('ABCDE')
              end
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
          pending do
            before do
              params = {:context_size => 10, :begin => @begin, :end => @end}
              @span, @prev_text, @next_text = @doc.span(params)
            end
            
            it 'should set get_ascii_text[begin...end] as span' do
              @span.should eql('345Δ7')
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
      
      context 'when encoding ascii' do
        before do
          @get_ascii_text = 'ascii text is this text about'
          @doc.stub(:get_ascii_text).and_return(@get_ascii_text)
        end

        context 'when context_size present' do
          pending do
            before do
              @context_size = 10
              params = {:encoding => 'ascii', :context_size => @context_size, :begin => @begin, :end => @end}
              @span, @prev_text, @next_text = @doc.span(params)
            end
            
            it 'should set get_ascii_text[begin...end] as span' do
              @span.should eql(@get_ascii_text)
            end
            
            it 'should set prev_text' do
              @prev_text.should eql(@get_ascii_text[(@context_size * -1)..-1])
            end
            
            it 'should set next_text' do
              @next_text.should eql(@get_ascii_text[0...@context_size])
            end
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
          pending do
            before do
              params = {:context_size => 3, :begin => @begin, :end => @end}
              @span, @prev_text, @next_text = @doc.span(params)
            end
            
            it 'should set get_ascii_text[begin...end] as span' do
              @span.should eql('123Δ567')
            end
            
            it 'should set prev_text' do
              @prev_text.should eql('->Δ')
            end
            
            it 'should set next_text' do
              @next_text.should eql('Δ<-')
            end
          end
        end
      end
      
      context 'when encoding ascii' do
        before do
          @get_ascii_text = 'ascii text is this text about'
          @doc.stub(:get_ascii_text).and_return(@get_ascii_text)
        end

        context 'when context_size present' do
          pending do
            before do
              @context_size = 3
              params = {:encoding => 'ascii', :context_size => @context_size, :begin => @begin, :end => @end}
              @span, @prev_text, @next_text = @doc.span(params)
            end
            
            it 'should set get_ascii_text[begin...end] as span' do
              @span.should eql(@get_ascii_text)
            end

            it 'should set prev_text' do
              @prev_text.should eql(@get_ascii_text[(@context_size * -1)..-1])
            end
            
            it 'should set next_text' do
              @next_text.should eql(@get_ascii_text[0...@context_size])
            end
          end
        end
      end
    end    
  end

  describe '#set_ascii_body' do
    before do
      @utf_text = 'utf_text'
      @ascii_text = 'ascii_text'
      @doc = FactoryGirl.create(:doc, body: @utf_text)
      @doc.stub(:get_ascii_text).and_return(@ascii_text)
      @doc.set_ascii_body
    end

    context 'when called' do
      it 'should set original_body' do
        expect(@doc.original_body).to eql(@utf_text)
      end

      it 'should set the body with ascii text' do
        expect(@doc.body).to eql(@ascii_text)
      end
    end
  end

  describe 'to_csv' do
    before do
      @doc = FactoryGirl.create(:doc)
      @span =['span', 'prev', 'next']
      @doc.stub(:span).and_return(@span)
    end

    context 'when params[:context_size] not present' do
      before do
        @csv = @doc.to_csv({:context_size => true})
      end

      it 'should return csv data' do
        @csv.should eql("left\tfocus\tright\n#{@span[1]}\t#{@span[0]}\t#{@span[2]}\n")
      end
    end

    context 'when params[:context_size] not present' do
      before do
        @csv = @doc.to_csv({})
      end

      it 'should return csv data' do
        @csv.should eql("focus\n#{@span[0]}\n")
      end
    end
  end
  
  describe 'spans_highlight' do
    before do
      @begin = 5
      @end = 10
      @body = 'ABCDE12345ABCDE1234567890'

      @doc = FactoryGirl.create(:doc, body: @body)
      @spans_highlight = @doc.highlight_span({begin: @begin, end: @end})
    end
    
    it 'should return prev, span, next text' do
      @spans_highlight.should eql("<span class='context'>#{@doc.body[0...@begin]}</span><span class='highlight'>#{@doc.body[@begin...@end]}</span><span class='context'>#{@doc.body[@end..@doc.body.length]}</span>")
    end
  end

  describe 'get_denotattions' do
    let(:doc) { FactoryGirl.create(:doc) } 
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:denotation_1) { FactoryGirl.create(:denotation, doc_id: 1, begin: 0, end: 5) }
    let(:denotation_2) { FactoryGirl.create(:denotation, doc_id: 1, begin: 1, end: 5) }
    let(:denotation_3) { FactoryGirl.create(:denotation, doc_id: 1, begin: 10, end: 15) }
    let(:denotations) { [denotation_1, denotation_2, denotation_3] }

    before do
      doc.stub(:denotations).and_return(denotations)
      denotations.stub(:from_projects).and_return(denotations)
      denotations.stub(:sort).and_return(nil)
    end

    context 'when project.present' do
      context 'when project is an Array' do
        it 'should set denotations.from_projects(project) as denotations' do
          expect(doc.denotations).to receive(:from_projects).with([project])
          doc.get_denotations([project])
        end
      end

      context 'when project is not an Array' do
        it 'should set denotations.from_projects(project) as denotations' do
          expect(doc.denotations).to receive(:from_projects).with([project])
          doc.get_denotations(project)
        end
      end
    end

    context 'when project.blank' do
      it 'should set denotations ' do
        expect(doc.denotations).not_to receive(:from_projects)
        doc.get_denotations(nil)
      end
    end

    describe 'text_aligner' do
      let(:text_aligner) { double(:text_aligner) }

      context 'when original_body.present' do
        before do
          doc.stub(:original_body).and_return('original_body')
          TextAlignment::TextAlignment.stub(:new).and_return(text_aligner)
          text_aligner.stub(:transform_denotations!).and_return(nil)
        end

        it 'should set TextAlignment::TextAlignment.new as text_aligner' do
          expect(TextAlignment::TextAlignment).to receive(:new).with(doc.original_body, doc.body, TextAlignment::MAPPINGS)
          doc.get_denotations(nil)
        end

        it 'should transform_denotations!' do
          expect( text_aligner ).to receive(:transform_denotations!)
          doc.get_denotations(nil)
        end
      end

      context 'when original_body.nil' do
        before do
          doc.stub(:original_body).and_return(nil)
        end

        it 'should not set TextAlignment::TextAlignment.new as text_aligner' do
          expect(TextAlignment::TextAlignment).not_to receive(:new).with(doc.original_body, doc.body, TextAlignment::MAPPINGS)
          doc.get_denotations(nil)
        end
      end
    end

    describe 'span' do
      context 'when span present' do
        let(:span) { {begin: 1, end: 9}}
        let(:denotation_1) { FactoryGirl.create(:denotation, doc_id: 1, begin: span[:begin] + 1 , end: span[:end] -1) }
        let(:denotation_2) { FactoryGirl.create(:denotation, doc_id: 1, begin: span[:begin] + 2 , end: span[:end]) }
        let(:denotation_3) { FactoryGirl.create(:denotation, doc_id: 1, begin: span[:begin] - 1 , end: span[:end]) }
        let(:denotation_4) { FactoryGirl.create(:denotation, doc_id: 1, begin: span[:begin] - 1 , end: span[:end] +1) }
        let(:denotation_5) { FactoryGirl.create(:denotation, doc_id: 1, begin: 0, end: 0) }
        let(:denotations) { [denotation_1, denotation_2, denotation_3, denotation_4, denotation_5 ] }

        before do
          doc.stub(:denotations).and_return(denotations)
        end

        it 'denotations should selected by condition' do
          expect{ doc.get_denotations(nil, span).select{|d| d.begin <= span[:begin] && d.end >= span[:end] }.to be_nil
          }        end
      end
    end

    describe 'sort denotations' do
      context 'when span present' do
        let(:span) { {begin: 1, end: 9}}
        let(:denotation_1) { FactoryGirl.create(:denotation, doc_id: 1, begin: 2, end: 6) }
        let(:denotation_2) { FactoryGirl.create(:denotation, doc_id: 1, begin: 2, end: 5) }
        let(:denotation_3) { FactoryGirl.create(:denotation, doc_id: 1, begin: 1, end: 9) }
        let(:denotation_4) { FactoryGirl.create(:denotation, doc_id: 1, begin: 1, end: 8) }
        let(:denotation_5) { FactoryGirl.create(:denotation, doc_id: 1, begin: 1, end: 7) }
        let(:denotations) { [denotation_1, denotation_2, denotation_3, denotation_4, denotation_5 ] }

        before do
          doc.stub(:denotations).and_return(denotations)
        end

        it 'denotations should be sorted by begin' do
          expect( doc.get_denotations(nil, span).first.begin ).to eql(1)
          expect( doc.get_denotations(nil, span).last.begin ).to eql(2)
        end
      end
    end
  end

  describe 'hdenotations' do
    let(:doc) { FactoryGirl.create(:doc) } 
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:span) { double(:span) }
    let(:get_hash) { double(:get_hash) }
    let(:get_hash_map) { double(:get_hash_map) }

    before do
      get_hash.stub(:map).and_return(nil)
      doc.stub(:get_denotations).and_return(get_hash)
    end

    it 'should call get_denotations' do
      expect(doc).to receive(:get_denotations).with(project, span)
      expect(get_hash).to receive(:map)
      doc.hdenotations(project, span)
    end
  end
  
  describe '#denotations_in_tracks' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_1.docs << @doc
      @project_2.docs << @doc
      @denotation_1 = FactoryGirl.create(:denotation, doc_id: @doc.id)
      FactoryGirl.create(:annotations_project, project: @project_1, annotation: @denotation_1)
      @denotation_2 = FactoryGirl.create(:denotation, doc_id: @doc.id)
      FactoryGirl.create(:annotations_project, project: @project_2, annotation: @denotation_2)
      @hdenotaions = 'hdenotations'
      @doc.stub(:hdenotations) do |project|
        if project == @project_1
          @denotation_1
        elsif project == @project_2
          @denotation_2
        end
      end
      @denotations_in_tracks = @doc.denotations_in_tracks
    end
    
    it 'should return project' do
      @denotations_in_tracks[0][:project].should eql(@project_1.name)
    end
    
    it 'should return denotations' do
      @denotations_in_tracks[0][:denotations].should eql(@denotation_1)
    end
    
    it 'should return project' do
      @denotations_in_tracks[1][:project].should eql(@project_2.name)
    end
    
    it 'should return denotations' do
      @denotations_in_tracks[1][:denotations].should eql(@denotation_2)
    end
  end

  describe 'hrelations' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:projects) { [project] }
    let(:relation_1) { FactoryGirl.create(:relation, obj_id: 1) }
    let(:relation_2) { FactoryGirl.create(:relation, obj_id: 1) }
    let(:relations) { [ relation_1, relation_2 ] }

    before do
      doc.stub_chain(:subcatrels, :from_projects).and_return(relations)
      doc.stub(:projects).and_return(projects)
      Modification.any_instance.stub(:get_hash).and_return(relation_1)
      relations.stub(:collect).and_return(relations)
      relations.stub(:select!).and_return(relations)
      relations.stub(:sort!).and_return(relations)
    end

    context 'when project present' do
      context 'when project == Array' do
        it 'should call catmods.from_projects with projects array' do
          expect(doc.subcatrels).to receive(:from_projects).with([ project ]) 
          doc.hrelations([ project ])
        end
      end

      context 'when project != Array' do
        it 'should call catmods.from_projects with projects array' do
          expect(doc.subcatrels).to receive(:from_projects).with([ project ]) 
          doc.hrelations(project)
        end
      end
    end

    context 'when project nil' do
      context 'when project == Array' do
        it 'should call catmods.from_projects with self.projects' do
          expect(doc.subcatrels).to receive(:from_projects).with(projects) 
          doc.hrelations(nil)
        end
      end
    end
    context 'when base_ids present' do
      it 'should collect hrelations by generate_divs' do
        expect( relations ).to receive(:select!)
        doc.hrelations(nil, [1])
      end
    end
  end

  describe 'spans_projects' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @not_denotation_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc)
      FactoryGirl.create(:annotations_project, project: @denotation_project_1, annotation: @denotation_1)
      @denotation_2 = FactoryGirl.create(:denotation, doc: @doc)
      FactoryGirl.create(:annotations_project, project: @denotation_project_2, annotation: @denotation_2)
      @denotation_3 = FactoryGirl.create(:denotation, doc: @doc)
      FactoryGirl.create(:annotations_project, project_id: 1000, annotation: @denotation_3)
      @denotations = double(:denotations)
      @doc.stub(:denotations).and_return(@denotations)
      @denotations.stub(:within_span).and_return([@denotation_1, @denotation_2, @denotation_3])
      @denotation_1.reload
      @denotation_2.reload
      @denotation_3.reload
      @projects = @doc.spans_projects({:begin => nil, :end => nil})
    end
    
    it 'should return projects which has doc.denotations as denotations' do
      @projects.should =~ [@denotation_project_1, @denotation_project_2]
    end
  end
  
  describe 'hmodifications' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:projects) { [project] }
    let(:modification_1) { FactoryGirl.create(:modification, obj_id: 1) }
    let(:modification_2) { FactoryGirl.create(:modification, obj_id: 1) }
    let(:modifications) { [ modification_1, modification_2 ] }

    before do
      doc.stub_chain(:catmods, :from_projects).and_return(modifications)
      doc.stub_chain(:subcatrelmods, :from_projects).and_return(modifications)
      modifications.stub(:+).and_return(modifications)
      doc.stub(:projects).and_return(projects)
      Modification.any_instance.stub(:get_hash).and_return(modification_1)
      modifications.stub(:collect).and_return(modifications)
      modifications.stub(:select!).and_return(modifications)
      modifications.stub(:sort!).and_return(modifications)
    end

    context 'when project present' do
      context 'when project == Array' do
        it 'should call catmods.from_projects with projects array' do
          expect(doc.catmods).to receive(:from_projects).with([ project ]) 
          expect(doc.subcatrelmods).to receive(:from_projects).with([ project ]) 
          doc.hmodifications([ project ])
        end
      end

      context 'when project != Array' do
        it 'should call catmods.from_projects with projects array' do
          expect(doc.catmods).to receive(:from_projects).with([ project ]) 
          expect(doc.subcatrelmods).to receive(:from_projects).with([ project ]) 
          doc.hmodifications(project)
        end
      end
    end

    context 'when project nil' do
      context 'when project == Array' do
        it 'should call catmods.from_projects with self.projects' do
          expect(doc.catmods).to receive(:from_projects).with(projects) 
          expect(doc.subcatrelmods).to receive(:from_projects).with(projects) 
          doc.hmodifications(nil)
        end
      end
    end

    context 'when base_ids present' do
      it 'should collect hmodifications by generate_divs' do
        expect( modifications ).to receive(:select!)
        doc.hmodifications(nil, [1])
      end
    end
  end

  describe 'destroy_project_annotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      @modification_1 = FactoryGirl.create(:modification, :hid => 'M1', :obj => @denotation)
      FactoryGirl.create(:annotations_project, project: @project, annotation: @modification_1)
      @relation_1 = FactoryGirl.create(:subcatrel, :hid => 'r1', :obj => @denotation, :subj => @denotation)
      FactoryGirl.create(:annotations_project, project: @project, annotation: @relation_1)
      @relation_2 = FactoryGirl.create(:subinsrel, :hid => 'r2', :obj => @denotation)
      FactoryGirl.create(:annotations_project, project: @project, annotation: @relation_2)
      @modification_2 = FactoryGirl.create(:modification, :hid => 'M2', :obj => @relation_1, :obj_type => @relation_1.class.to_s)
      FactoryGirl.create(:annotations_project, project: @project, annotation: @modification_2)
      @modification_3 = FactoryGirl.create(:modification, :hid => 'M3', :obj => @relation_2, :obj_type => @relation_2.class.to_s)
      FactoryGirl.create(:annotations_project, project: @project, annotation: @modification_3)
      @project.reload
    end

    context 'when project present' do
      it 'should call destroy_all' do
        denotations = double(:denotations)
        denotations.stub(:destroy_all).and_return(nil)
        @doc.stub_chain(:denotations, :from_projects).and_return(denotations)
        denotations.should_receive(:destroy_all)
        @doc.destroy_project_annotations(@project) 
      end
    end
  end


  describe 'to_hash' do
    before do
      @doc = FactoryGirl.create(:doc, body: 'AB', sourcedb: 'sdb', sourceid: 'sdi', serial: 0, section: 'section', source: 'http://to.to')
    end

    it 'should return converted hash' do
      expect(@doc.to_hash).to eql({text: @doc.body, sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, divid: @doc.serial, section: @doc.section, source_url: @doc.source})
    end
  end

  describe 'to_list_hash' do
    before do
      @doc = FactoryGirl.create(:doc, sourcedb: 'sdb', sourceid: 'sdi', serial: 0, section: 'section', source: 'http://to.to', body: 'AB')
    end

    context 'when doc_type is doc' do
      it 'should return sourcedb, sourceid, url' do
        @doc.to_list_hash('doc').should eql({sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_url(@doc.sourcedb, @doc.sourceid)})
      end
    end

    context 'when doc_type is div' do
      it 'should return sourcedb, sourceid, div_url' do
        @doc.to_list_hash('div').should eql({sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, divid: @doc.serial, section: @doc.section, url: Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_index_url(@doc.sourcedb, @doc.sourceid)})
      end
    end
  end

  describe 'self.to_tsv' do
    before do
      @doc_1 = double(:doc_1)
      @list_hash_1 = {key_1: 'val_1_1', key_2: 'val_1_2'}
      @doc_1.stub(:to_list_hash).and_return(@list_hash_1)
      @doc_2 = double(:doc_2)
      @list_hash_2 = {key_1: 'val_2_1', key_2: 'val_2_2'}
      @doc_2.stub(:to_list_hash).and_return(@list_hash_2)
      @docs = [@doc_1, @doc_2]
    end

    it 'should return doc.to_list_hash as tab separated csv' do
      Doc.to_tsv(@docs, 'doc_type').should eql("#{@list_hash_1.keys.first}\t#{@list_hash_1.keys.last}\n#{@list_hash_1[:key_1]}\t#{@list_hash_1[:key_2]}\n#{@list_hash_2[:key_1]}\t#{@list_hash_2[:key_2]}\n")
    end
  end
  
  describe 'sql_find' do
    before do
      @current_user = FactoryGirl.create(:user)
      @accessible_doc = FactoryGirl.create(:doc)
      @project_doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
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
            Doc.sql_find({:sql => 'select * from docs where id = 1000'}, @current_user, @project).should be_blank
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
            Doc.sql_find({:sql => 'select * from docs where id = 1000'}, nil, @project).should be_blank
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
    
    context 'when user.root is false' do
      before do
        @user = FactoryGirl.create(:user, root: false)
      end

      context 'when doc.created_by? == true' do
        before do
          @doc.stub(:created_by?).and_return(true)
        end

        it 'should return true' do
          @doc.updatable_for?(@user).should be_true
        end
      end

      context 'when doc.created_by? == false' do
        before do
          @doc.stub(:created_by?).and_return(false)
        end

        it 'should return false' do
          @doc.updatable_for?(@user).should be_false
        end
      end
    end
  end

  describe 'created_by?' do
    let(:current_user) { FactoryGirl.create(:user) }

    context 'when created_by current_user' do
      let(:doc) { FactoryGirl.create(:doc, sourcedb: "sdb#{Doc::UserSourcedbSeparator}#{current_user.username}") }

      it 'should return true' do
        expect(doc.created_by?(current_user)).to be_true
      end
    end

    context 'when not created_by current_user' do
      let(:doc) { FactoryGirl.create(:doc, sourcedb: "sdb") }

      it 'should return false' do
        expect(doc.created_by?(current_user)).to be_false
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

  describe '.has_divs?' do
    before do
      @sourcedb = 'sourcedb'
      @sourceid = 'sourceid'
    end

    context 'when size > 1' do
      before do
        Doc.stub(:same_sourcedb_sourceid).and_return(double(:db, {size: 2}))
      end

      it 'should call same_sourcedb_sourceid with sourcedb and sourceid' do
        expect(Doc).to receive(:same_sourcedb_sourceid).with(@sourcedb, @sourceid)
        Doc.has_divs?(@sourcedb, @sourceid)
      end

      it 'should return true' do
        expect(Doc.has_divs?(@sourcedb, @sourceid)).to be_true
      end
    end

    context 'when size = 1' do
      before do
        Doc.stub(:same_sourcedb_sourceid).and_return(double(:db, {size: 1}))
      end

      it 'should call same_sourcedb_sourceid with sourcedb and sourceid' do
        expect(Doc).to receive(:same_sourcedb_sourceid).with(@sourcedb, @sourceid)
        Doc.has_divs?(@sourcedb, @sourceid)
      end

      it 'should return false' do
        expect(Doc.has_divs?(@sourcedb, @sourceid)).to be_false
      end
    end
  end

  describe 'has_divs?' do
    before do
      @sourcedb = 'sourcedb'
      @sourceid = 'sourceid'
      @doc = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid.to_s)  
    end

    context 'when size > 1' do
      before do
        Doc.stub(:same_sourcedb_sourceid).and_return(double(:db, {size: 2}))
      end

      it 'should call same_sourcedb_sourceid with sourcedb and sourceid' do
        expect(Doc).to receive(:same_sourcedb_sourceid).with(@sourcedb, @sourceid)
        Doc.has_divs?(@sourcedb, @sourceid)
      end

      it 'should return true' do
        expect(Doc.has_divs?(@sourcedb, @sourceid)).to be_true
      end
    end

    context 'when size = 1' do
      before do
        Doc.stub(:same_sourcedb_sourceid).and_return(double(:db, {size: 1}))
      end

      it 'should call same_sourcedb_sourceid with sourcedb and sourceid' do
        expect(Doc).to receive(:same_sourcedb_sourceid).with(@sourcedb, @sourceid)
        Doc.has_divs?(@sourcedb, @sourceid)
      end

      it 'should return false' do
        expect(Doc.has_divs?(@sourcedb, @sourceid)).to be_false
      end
    end
  end
  
  describe 'has_divs?' do
    before do
      @sourcedb = 'sourcedb'
      @sourceid = 123456789
      @doc = FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid.to_s)  
    end
    
    context 'when same sourcedb and sourceid doc blank' do
      it 'shoud return false' do
        @doc.has_divs?.should be_false
      end
    end
    
    context 'when same sourcedb and sourceid doc present' do
      before do
        FactoryGirl.create(:doc, :sourcedb => @sourcedb, :sourceid => @sourceid.to_s)  
      end
      
      it 'shoud return true' do
        @doc.has_divs?.should be_true
      end
    end
  end

  describe 'self.get_div_ids' do
    before do
      @sourcedb = 'sourcedb'
      @sourceid = 'sourceid'
      @serial_1 = 1
      @serial_2 = 2
      FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid.to_s, serial: @serial_1)  
      FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid.to_s, serial: @serial_2)  
      Doc.stub(:same_sourcedb_sourceid).and_return(Doc)
    end

    it 'should return same_sourcedb_sourceid serials map' do
      expect(Doc.get_div_ids(@sourcedb, @sourceid)).to match_array([@serial_1, @serial_2])
    end
  end

  describe 'attach_sourcedb_suffix' do
    pending 'before_validation comennted' do
      context 'when sourcedb include : == false' do
        before do
          @sourcedb = 'sourcedb'
          @username = 'user name'
        end

        context 'when username present' do
          before do
            @doc = FactoryGirl.build(:doc, sourcedb: @sourcedb, username: @username)
          end

          it 'should attach suffix' do
            @doc.valid? 
            @doc.sourcedb.should eql("#{@sourcedb}#{Doc::UserSourcedbSeparator}#{@username}")
          end
        end

        context 'when username blank' do
          before do
            @doc = FactoryGirl.build(:doc, sourcedb: @sourcedb)
          end

          it 'should not attach suffix' do
            @doc.valid? 
            @doc.sourcedb.should eql("#{@sourcedb}")
          end
        end
      end

      context 'when sourcedb include : == true' do
        before do
          @sourcedb = 'sourcedb:username'
          @doc = FactoryGirl.build(:doc, sourcedb: @sourcedb)
        end

        it 'should not attach suffix' do
          @doc.valid? 
          @doc.sourcedb.should eql("#{@sourcedb}")
        end
      end
    end
  end
end
