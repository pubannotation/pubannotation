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
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :id => 3, :project_id => @project_1.id)
      @subj = FactoryGirl.create(:denotation, :doc => @doc, :id => 4)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @subcatrel = FactoryGirl.create(:subcatrel, :subj_id => @subj.id , :id => 4, :obj => @denotation, project: @project)
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
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :doc => @doc, :project => @project)
      @subj = FactoryGirl.create(:denotation, :doc => @doc)
      @subcatrel = FactoryGirl.create(:subcatrel, :subj_id => @subj.id , :obj => @denotation, :project => @project)
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
  
  describe 'scope' do
    describe 'pmdocs' do
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
    
    describe 'pmcdocs' do
      before do
        @pmcdocs_count = 3
        @pmcdocs_count.times do |time|
          FactoryGirl.create(:doc, :sourcedb => 'PMC', sourceid: time.to_s)
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
    
    describe 'project_name' do
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

  describe 'descriptor' do
    let(:doc) { FactoryGirl.create(:doc) }
    
    context 'when has_divs? true' do
      before do
        doc.stub(:has_divs?).and_return(true)
      end

      it 'should return string includes sourcedb, sourceid and serial' do
        expect( doc.descriptor ).to eql("#{doc.sourcedb}:#{doc.sourceid}-#{doc.serial}")
      end
    end

    context 'when has_divs? false' do
      before do
        doc.stub(:has_divs?).and_return(false)
      end

      it 'should return string includes sourcedb and sourceid' do
        expect( doc.descriptor ).to eql("#{doc.sourcedb}:#{doc.sourceid}")
      end
    end
  end

  describe 'get_doc' do
    let(:sourcedb) { 'sdb' }
    let(:sourceid) { '123456' }
    let(:divid) { 'divid' }

    context 'when docspec sourcedb sourceid present' do
      context 'when divid present' do
        it 'should call find_by_sourcedb_and_sourceid_and_serial' do
          expect(Doc).to receive(:find_by_sourcedb_and_sourceid_and_serial).with(sourcedb, sourceid, divid)
          Doc.get_doc({sourcedb: sourcedb, sourceid: sourceid, divid: divid })
        end
      end

      context 'when divid nil' do
        it 'should call find_by_sourcedb_and_sourceid_and_serial' do
          expect(Doc).to receive(:find_by_sourcedb_and_sourceid_and_serial).with(sourcedb, sourceid, 0)
          Doc.get_doc({sourcedb: sourcedb, sourceid: sourceid})
        end
      end
    end

    context 'when docspec sourcedb sourceid nil' do
      it 'should return nil' do
        expect( Doc.get_doc({}) ).to be_nil
      end
    end
  end

  describe 'exist?' do
    context 'when get_doc is not nil' do
      before do
        Doc.stub(:get_doc).and_return([])
      end

      it 'should return true' do
        expect(Doc.exist?('')).to be_true
      end
    end

    context 'when get_doc is nil' do
      before do
        Doc.stub(:get_doc).and_return(nil)
      end

      it 'should return false' do
        expect(Doc.exist?('')).to be_false
      end
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

  describe 'search_docs' do
    let(:sourcedb) { 'sdb' }
    let(:sourceid) { '123456' }
    let(:body) { 'body' }
    let(:doc_1) { FactoryGirl.create(:doc, sourceid: sourceid, sourcedb: sourcedb, body: body) }

    context 'when params sourcedb, sourceid and body present' do
      it '' do
        expect(Doc).to receive(:search)
        Doc.search_docs({sourcedb: sourcedb, sourceid: sourceid, body: body})
      end
    end
  end

  describe 'import_from_sequence', elasticsearch: true do
    # TODO just assserting about call index_diff
    let(:divs) { [{body: 'b', heading: 'heading'}] }
    let(:doc_sequence) { double(:doc_sequence, divs: divs, source_url: 'src')}

    before do
      divs.stub(:source_url).and_return('src')
      Object.stub_chain(:const_get, :new).and_return(doc_sequence)
      Doc.stub(:index_diff).and_return(nil)
    end

    it 'should call index_diff' do
      expect(Doc).to receive(:index_diff)
      Doc.import_from_sequence('PMC', '123456')
    end
  end

  describe 'create_doc', elasticsearch: true do
    # TODO just assserting about call index_diff

    before do
      Doc.stub(:index_diff).and_return(nil)
      Doc.stub(:divs_hash).and_return(nil)
    end

    it 'should call index_diff' do
      expect(Doc).to receive(:index_diff)
      Doc.create_doc(nil)
    end
  end

  describe 'create_divs', elasticsearch: true do
    # TODO just assserting about call index_diff

    before do
      Doc.stub(:index_diff).and_return(nil)
    end

    it 'should call index_diff' do
      expect(Doc).to receive(:index_diff)
      Doc.create_divs(nil)
    end
  end

  describe 'revise' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:body) { 'new body' }

    context 'when body == self.body' do
      it 'should return nil' do
        expect(doc.revise(doc.body)).to be_nil
      end
    end

    context 'when text_aligner is nil' do
      before do
        TextAlignment::TextAlignment.stub(:new).and_return(nil)
      end

      it 'should return nil' do
        expect{ doc.revise(body) }.to raise_error
      end
    end

    context 'when text_aligner similarity is too low' do
      before do
        TextAlignment::TextAlignment.stub(:new).and_return(double(:text_aligner, similarity: 0.1))
      end

      it 'should return nil' do
        expect{ doc.revise(body) }.to raise_error
      end
    end

    context 'successfully finished' do
      let(:denotation) { double(:denotation) }
      let(:denotations) { [denotation] }
      let(:text_aligner) { double(:text_aligner, similarity: 1) }

      before do
        doc.stub(:denotations).and_return(denotations)
        denotation.stub(:save).and_return(true)
        TextAlignment::TextAlignment.stub(:new).and_return(text_aligner)
        text_aligner.stub(:transform_denotations!).and_return(denotations)
      end

      it 'should update body' do
        doc.revise(body) 
        expect( doc.body ).to eql(body)
      end

      it 'should call transform_denotations!' do
        expect( text_aligner ).to receive(:transform_denotations!).with(denotations)
        doc.revise(body) 
      end

      it 'should call transform_denotations!' do
        expect( denotation ).to receive(:save)
        doc.revise(body) 
      end
    end
  end

  describe 'uptodate' do
    let(:div) { double(:div, body: 'div body', sourcedb: 'sourcedb', sourceid: 'sourceid') }
    let(:divs) { [div] }

    context 'when new_divs.size != divs size' do
      before do
        Object.stub_chain(:const_get, :new, :divs).and_return(5)
      end

      it 'should raise error' do
        expect{ Doc.uptodate(divs) }.to raise_error
      end
    end

    context 'when new_divs.size == divs size' do
      let(:new_divs) { [{body: 'new body'}] }
      before do
        Object.stub_chain(:const_get, :new, :divs).and_return(new_divs)
      end

      it 'should call revise' do
        expect(div).to receive(:revise).with(new_divs[0][:body])
        Doc.uptodate(divs) 
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
        before do
          FactoryGirl.create(:user)
          @doc_3relations = FactoryGirl.create(:doc, :id => 5)
          @project_1 = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
          3.times do
            denotation = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_3relations)
            FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id, project: @project_1)
          end
  
          @project_2 = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
          @doc_2relations = FactoryGirl.create(:doc, :id => 4)
          2.times do
            denotation = FactoryGirl.create(:denotation, :project => @project_2, :doc => @doc_2relations)
            FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id, project: @project_2)
          end
          
          @project_3 = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
          @doc_1relations = FactoryGirl.create(:doc, :id => 3)
          denotation = FactoryGirl.create(:denotation, :project => @project_3, :doc => @doc_1relations)
          FactoryGirl.create(:subcatrel, :obj => denotation, :subj_id => denotation.id, project: @project_3)
          
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
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @same_sourceid_docs_count.times do |i|
        id = i + 1
        doc = FactoryGirl.create(:doc, :id => id,  :sourceid => '123456')
        denotation = FactoryGirl.create(:denotation, :id => id, :project => @project, :doc => doc)
        # create relations
        @relations_size.times do |i|
          id = i + 1
          FactoryGirl.create(:relation, :subj_id => denotation.id, :subj_type => 'Denotation', project: @project, :obj_id => id)
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

  describe 'span_url' do
    let(:doc) { FactoryGirl.create(:doc, sourceid: 'PMC', sourcedb: 'sourcedb') }
    let(:span) { {begin: 1, end: 5} }

    before do
      doc.stub(:has_divs?).and_return(true)
    end

    context 'when has_divs? == true' do
      it 'should return url' do
        expect( doc.span_url(span) ).to eql("http://test.host/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/divs/#{doc.serial}/spans/#{span[:begin]}-#{span[:end]}")
      end
    end

    context 'when has_divs? == false' do
      before do
        doc.stub(:has_divs?).and_return(false)
      end

      it 'should return url' do
        expect( doc.span_url(span) ).to eql("http://test.host/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/spans/#{span[:begin]}-#{span[:end]}")
      end
    end
  end

  describe 'spans_index' do
    let(:doc) { FactoryGirl.create(:doc, sourceid: 'PMC', sourcedb: 'sourcedb') }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:hdenotation) { {id: 1, span: [{span: 'span_1'}, {span: 'span_2'}]} }
    let(:span_url) { 'span_url' }

    before do
      doc.stub(:hdenotations).and_return([hdenotation])
      doc.stub(:span_url).and_return(span_url)
    end

    it 'should return map result' do
      expect( doc.spans_index ).to eql([{id: hdenotation[:id], span: [{span: hdenotation[:span][0][:span]}, {span: hdenotation[:span][1][:span]}], obj: span_url}])
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
      @spans_highlight.should eql("#{@doc.body[0...@begin]}<span class='highlight'>#{@doc.body[@begin...@end]}</span>#{@doc.body[@end..@doc.body.length]}")
    end
  end

  describe 'get_denotattions' do
    let!(:doc) { FactoryGirl.create(:doc) } 
    let!(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let!(:denotation_1) { FactoryGirl.create(:denotation, project: project) }
    let!(:denotation_2) { FactoryGirl.create(:denotation, project: project) }
    let!(:denotation_3) { FactoryGirl.create(:denotation, project: project) }
    let!(:denotations) { Denotation.where('id IN (?)', [denotation_1.id, denotation_2.id, denotation_3.id]) }

    before do
      doc.stub_chain(:denotations, :where).and_return(denotations)
      denotations.stub(:sort!).and_return(nil)
    end

    context 'when project.present' do
      context 'when project is an Array' do
        it 'should set denotations.project_id in project.ids' do
          expect(doc.denotations).to receive(:where).with('denotations.project_id IN (?)', [project.id])
          doc.get_denotations([project])
        end
      end

      context 'when project is not an Array' do
        it 'should set denotations.project_id equal project.id' do
          expect(doc.denotations).to receive(:where).with('denotations.project_id = ?', project.id)
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
        let(:span_1) { FactoryGirl.create(:span, doc_id: 1, begin: span[:begin] + 1 , end: span[:end] -1) }

        let(:denotation_1) { FactoryGirl.create(:denotation, subj: span_1) }
        let(:span_2) { FactoryGirl.create(:span, doc_id: 1, begin: span[:begin] + 2 , end: span[:end]) }
        let(:denotation_2) { FactoryGirl.create(:denotation, subj: span_2) }
        let(:span_3) { FactoryGirl.create(:span, doc_id: 1, begin: span[:begin] - 1 , end: span[:end]) }
        let(:denotation_3) { FactoryGirl.create(:denotation, subj: span_3) }
        let(:span_4) { FactoryGirl.create(:span, doc_id: 1, begin: span[:begin] - 1 , end: span[:end] +1) }
        let(:denotation_4) { FactoryGirl.create(:denotation, subj: span_4) }
        let(:span_5) { FactoryGirl.create(:span, doc_id: 1, begin: 0, end: 0) }
        let(:denotation_5) { FactoryGirl.create(:denotation, subj: span_5) }
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
        let(:span_1) { FactoryGirl.create(:span, doc_id: 1, begin: 2, end: 6) }
        let(:denotation_1) { FactoryGirl.create(:denotation, subj: span_1) }
        let(:span_2) { FactoryGirl.create(:span, doc_id: 1, begin: 2, end: 5) }
        let(:denotation_2) { FactoryGirl.create(:denotation, subj: span_2) }
        let(:span_3) { FactoryGirl.create(:span, doc_id: 1, begin: 1, end: 9) }
        let(:denotation_3) { FactoryGirl.create(:denotation, subj: span_3) }
        let(:span_4) { FactoryGirl.create(:span, doc_id: 1, begin: 1, end: 8) }
        let(:denotation_4) { FactoryGirl.create(:denotation, subj: span_4) }
        let(:span_5) { FactoryGirl.create(:span, doc_id: 1, begin: 1, end: 7) }
        let(:denotation_5) { FactoryGirl.create(:denotation, subj: span_5) }
        let(:denotations) { [denotation_1, denotation_2, denotation_3, denotation_4, denotation_5 ] }

        before do
          doc.stub(:denotations).and_return(denotations)
        end

        it 'denotations should be sorted by begin' do
          expect( doc.get_denotations(nil, span).first.span.begin ).to eql(1)
          expect( doc.get_denotations(nil, span).last.span.begin ).to eql(2)
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
        pending do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
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
    end
    
    context 'when options[:span] present' do
      before do
        @denotation_within_span_1 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 40, :end => 49)
        @denotation_within_span_2 = FactoryGirl.create(:denotation, :project => @project_1, :doc => @doc_1, :begin => 41, :end => 49)
        @denotations = @doc_1.hdenotations(@project_1, {:begin => 40, :end => 50})
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
  
  describe '#denotations_in_tracks' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:span) { 'span' }
    let(:hdenotations) { 'hdenotations' }

    before do
      doc.stub(:hdenotations).and_return(hdenotations)
    end

    context 'when project present' do
      context 'when project respond_to each' do
        let(:project) { [FactoryGirl.create(:project, user: FactoryGirl.create(:user))] }

        it 'should call doc.hdenotations with project[n] and span' do
          expect( doc ).to receive(:hdenotations).with(project[0], span)
          doc.denotations_in_tracks(project, span)
        end

        it 'should return hash includes project[n].name and hdenotations' do
          expect( doc.denotations_in_tracks(project, span) ).to eql([ {project: project[0].name, denotations: hdenotations} ])
        end
      end

      context 'when project not respond_to each' do
        let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }

        it 'should call doc.hdenotations with project and span' do
          expect( doc ).to receive(:hdenotations).with(project, span)
          doc.denotations_in_tracks(project, span)
        end

        it 'should return hash includes project.name and hdenotations' do
          expect( doc.denotations_in_tracks(project, span) ).to eql([ {project: project.name, denotations: hdenotations} ])
        end
      end
    end

    context 'when project nil' do
      let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }

      before do
        doc.stub(:projects).and_return([project])
      end

      it 'should call doc.hdenotations with doc.projects[n] and span' do
        expect( doc ).to receive(:hdenotations).with(project, span)
        doc.denotations_in_tracks(nil, span)
      end

      it 'should return hash includes doc.projects[n].name and hdenotations' do
        expect( doc.denotations_in_tracks(nil, span) ).to eql([ {project: project.name, denotations: hdenotations} ])
      end
    end
  end

  describe 'annotations_count' do
    let(:doc) { FactoryGirl.create(:doc, denotations_count: 5) }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:denotations_count) { 3 }
    let(:subcatrels_count) { 4 }
    let(:catmods_count) { 5 }
    let(:subcatrelmods_count) { 6 }
    let(:hdenotation) { {id: 'hdenotation'} }
    let(:hrelation) { {id: 'hrelation'} }
    let(:hmodification) { {id: 'hmodification'} }
    let(:span) { 'span' }

    before do
      doc.stub_chain(:denotations, :count).and_return(denotations_count)
      doc.stub_chain(:subcatrels, :count).and_return(subcatrels_count)
      doc.stub_chain(:catmods, :count).and_return(catmods_count)
      doc.stub_chain(:subcatrelmods, :count).and_return(subcatrelmods_count)
      doc.stub(:hdenotations).and_return([hdenotation])
      doc.stub(:hrelations).and_return([hrelation])
      doc.stub(:hmodifications).and_return([hmodification])
    end

    context 'when project.nil && span.nil' do
      it 'should return self denotations.count, subcatrels.count, catmods.count and subcatrelmods.count' do
        expect(doc.annotations_count(nil, nil)).to eql(denotations_count + subcatrels_count + catmods_count + subcatrelmods_count)
      end
    end

    context 'when project.present || span.present' do
      it 'should return self denotations.size, subcatrels.size, catmods.size and subcatrelmods.size' do
        expect(doc.annotations_count(project, span)).to eql(3)
      end
    end
  end

  describe 'hrelations' do
    before do
      @doc = FactoryGirl.create(:doc)
      FactoryGirl.create(:user)
    end
    
    context 'when options[:spans] present' do
      before do
        @denotation_1 = FactoryGirl.create(:denotation, :hid=> 'T1', :doc => @doc, :begin => 2, :end => 4)
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @relation_1 = FactoryGirl.create(:relation, project: @project_1, :hid => 'H1', :subj_id => @denotation_1.id, :obj_id => @denotation_1.id, :obj_type => 'Denotation', :subj_type => 'Denotation')
        @relation_2 = FactoryGirl.create(:relation, project: @project_2, :hid => 'H2', :subj_id => @denotation_1.id, :obj_id => @denotation_1.id, :obj_type => 'Denotation', :subj_type => 'Denotation')
      end
      
      context 'when project blank' do
        before do
          @hrelations  = @doc.hrelations(nil, ['T1'])
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
          @project_1.stub_chain(:relations, :where).and_return([@relation_2])
          @hrelations  = @doc.hrelations(@project_1, ['T1'] )
        end

        it 'should return project.relations' do
          @hrelations.should eql([
              {:id => @relation_1.hid, :pred => @relation_1.pred, :subj => @denotation_1.hid, :obj => @denotation_1.hid} 
          ])
        end
      end
    end
    
    context 'when options blank' do
      before do
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @instance_1 = FactoryGirl.create(:instance, :obj => @denotation_1, :project => @project_1)
        @relation_1 = FactoryGirl.create(:subcatrel, :obj => @denotation_1, :subj => @denotation_1, :project => @project_1)
        @relation_2 = FactoryGirl.create(:subinsrel, :obj => @instance_1, :project => @project_1)

        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @denotation_2 = FactoryGirl.create(:denotation, :doc => @doc, :begin => 2, :end => 4)
        @instance_2 = FactoryGirl.create(:instance, :obj => @denotation_2, :project => @project_2)
        @relation_3 = FactoryGirl.create(:subcatrel, :obj => @denotation_2, :subj => @denotation_2, :project => @project_2)
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
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
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

  describe 'projects_within_span' do
    let(:doc) { FactoryGirl.create(:doc, body: '12345678901234567890') }
    let(:denotation_1) { double(:denotation) }
    let(:denotation_2) { double(:denotation) }
    let(:denotation_3) { double(:denotation) }
    let(:denotation_4) { double(:denotation) }
    let(:project_1) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:project_2) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }

    before do
      denotation_1.stub(:project).and_return(project_1)
      denotation_2.stub(:project).and_return(project_2)
      denotation_3.stub(:project).and_return(project_2)
      denotation_4.stub(:project).and_return(nil)
      doc.stub(:get_denotations).and_return([denotation_1, denotation_2, denotation_3, denotation_4])
    end
    
    it 'should return get_denotations projects uniq' do
      expect( doc.projects_within_span('span') ).to eql([project_1, project_2])
    end
  end
  
  describe 'spans_projects' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation_project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation_project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @not_denotation_project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation_1 = FactoryGirl.create(:denotation, :project => @denotation_project_1, :doc => @doc)
      @denotation_2 = FactoryGirl.create(:denotation, :project => @denotation_project_2, :doc => @doc)
      @denotation_3 = FactoryGirl.create(:denotation, :project_id => 1000, :doc => @doc)
      @denotations = double(:denotations)
      @doc.stub(:denotations).and_return(@denotations)
      @denotations.stub(:within_span).and_return([@denotation_1, @denotation_2, @denotation_3])
      @projects = @doc.spans_projects({:begin => nil, :end => nil})
    end
    
    it 'should return projects which has doc.denotations as denotations' do
      @projects.should =~ [@denotation_project_1, @denotation_project_2]
    end
  end

  describe 'json_hash' do
    before do
      @doc = FactoryGirl.create(:doc, section: 'SECTION', source: 'http://sour.ce')
    end

    context 'when has_divs? == true' do
      before do
        @doc.stub(:has_divs?).and_return(true)
        @json_hash = @doc.json_hash
      end

      it 'should return doc.id' do
        @json_hash[:id].should eql(@doc.id) 
      end

      it 'should return doc.body' do
        @json_hash[:text].should eql(@doc.body) 
      end

      it 'should return doc.sourcedb' do
        @json_hash[:sourcedb].should eql(@doc.sourcedb) 
      end

      it 'should return doc.sourceid' do
        @json_hash[:sourceid].should eql(@doc.sourceid) 
      end

      it 'should return doc.section' do
        @json_hash[:section].should eql(@doc.section) 
      end

      it 'should return doc.source' do
        @json_hash[:source_url].should eql(@doc.source) 
      end

      it 'should return doc.serial' do
        @json_hash[:divid].should eql(@doc.serial) 
      end
    end

    context 'when has_divs? == false' do
      pending 'divid is required when create docs from json' do
        before do
          @doc.stub(:has_divs?).and_return(false)
          @json_hash = @doc.json_hash
        end

        it 'should return doc.serial' do
          @json_hash[:divid].should be_nil
        end
      end
    end
  end
  
  describe 'hmodifications' do
    before do
      @doc = FactoryGirl.create(:doc)
      @user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @user)
    end
      
    context 'when base_ids present' do
      before do
        @denotation_1 = FactoryGirl.create(:denotation, :project => @project, :hid => 'T1', :doc => @doc, :begin => 2, :end => 4)
        @modification_1 = FactoryGirl.create(:modification, :project => @project, :obj => @denotation_1)
        @hmodifications = @doc.hmodifications(@project,  ['T1'])
      end
      
      it 'should return denotations.within_span.modifications' do
        @hmodifications.should eql([{:id => @modification_1.hid, :pred => @modification_1.pred, :obj => @denotation_1.hid}])
      end
    end
    
    context 'when options[:spans] blank' do
      before do
        @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @denotation_1 = FactoryGirl.create(:denotation, :doc => @doc)
        # @instance_1 = FactoryGirl.create(:instance, :obj => @denotation_1, :project => @project_1)
        @modification_1 = FactoryGirl.create(:modification, :hid => 'M1', :obj => @denotation_1, :project => @project_1)
        @relation_1 = FactoryGirl.create(:subcatrel, :hid => 'r1', :obj => @denotation_1, :subj => @denotation_1, :project => @project_1)
        @relation_2 = FactoryGirl.create(:subinsrel, :hid => 'r2', :obj => @denotation_1, :project => @project_1)
        @modification_2 = FactoryGirl.create(:modification, :hid => 'M2', :obj => @relation_1, :obj_type => @relation_1.class.to_s, :project => @project_1)
        @modification_3 = FactoryGirl.create(:modification, :hid => 'M3', :obj => @relation_2, :obj_type => @relation_2.class.to_s, :project => @project_1)

        @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @denotation_2 = FactoryGirl.create(:denotation, :doc => @doc)
        # @instance_2 = FactoryGirl.create(:instance, :obj => @denotation_2, :project => @project_2)
        @modification_4 = FactoryGirl.create(:modification, :hid => 'M4', :obj => @denotation_2, :project => @project_2)
        @relation_3 = FactoryGirl.create(:subcatrel, :hid => 'r3', :obj => @denotation_2, :subj => @denotation_2, :project => @project_2)
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

  describe 'hannotations' do
    let(:doc) { FactoryGirl.create(:doc, body: '12345678901234567890') }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }

    context 'when has_divs? == true' do
      before do
        doc.stub(:has_divs?).and_return(true)
      end

      it 'should set doc_sourcedb_sourceid_divs_show_path as annotations[:target]' do
        expect( doc.hannotations(nil, nil, nil)[:target] ).to eql(Rails.application.routes.url_helpers.doc_sourcedb_sourceid_divs_show_path(doc.sourcedb, doc.sourceid, doc.serial, only_path: false))
      end

      it 'should set doc.serial as annotations[:divid]' do
        expect( doc.hannotations(nil, nil, nil)[:divid] ).to eql(doc.serial)
      end
    end

    context 'when has_divs? == false' do
      before do
        doc.stub(:has_divs?).and_return(false)
      end

      it 'should set doc_sourcedb_sourceid_show_path as annotations[:target]' do
        expect( doc.hannotations(nil, nil, nil)[:target] ).to eql(Rails.application.routes.url_helpers.doc_sourcedb_sourceid_show_path(doc.sourcedb, doc.sourceid, only_path: false))
      end
    end

    context 'when span present' do
      it 'should return trimmed doc.body as annotations[:text]' do
        expect( doc.hannotations(nil, {begin: 0, end: 6})[:text]).not_to eql(doc.body)
      end
    end

    context 'when span present' do
      it 'should return doc.body as annotations[:text]' do
        expect( doc.hannotations(nil, nil)[:text]).to eql(doc.body)
      end
    end

    context 'when project.present and project not respond_to each' do
      let(:hdenotation_span) { {begin: 9, end: 14} }
      let(:hdenotations) { [{id: 'hdenotation', span: hdenotation_span}] }
      let(:hrelations) { [{id: 'hrelation'}] }
      let(:hmodifications) { [{id: 'hmodification'}] }
      let(:span) { {begin: 5, end: 10} }

      before do
        doc.stub(:hdenotations).and_return(hdenotations)
        doc.stub(:hrelations).and_return(hrelations)
        doc.stub(:hmodifications).and_return(hrelations)
      end

      context 'when span present' do
        it 'should minus from hdenotations span begin and end' do
          expect( doc.hannotations(project, span)[:denotations][0][:span][:begin] ).not_to eql(9)
        end
      end

      context 'when span nil' do
        it 'should not minus from hdenotations span begin and end' do
          expect( doc.hannotations(project, nil)[:denotations][0][:span][:begin] ).to eql(9)
        end
      end
    end

    context 'when project.nil or project not respond_to each' do
      let(:hdenotations) { [{id: 'hdenotation'}] }
      let(:span) { {begin: 5, end: 10} }
      let(:hrelations) { 'hrelations' }
      let(:hdenotation_ids) { ['hdenotations ids'] }
      let(:hrelations_ids) { ['relations ids'] }
      let(:hrelations) { 'hrelations' }
      let(:hmodifications) { 'hmodification' }
      let(:project_namespaces) { 'project_namespaces' }

      before do
        doc.stub(:projects).and_return([ project ])
        doc.stub(:hdenotations).and_return(hdenotations)
        hdenotations.stub(:each).and_return(hdenotation_ids)
        hdenotations.stub(:collect).and_return(hdenotation_ids)
        doc.stub(:hrelations).and_return(hrelations)
        hrelations.stub(:collect).and_return(hrelations_ids)
        doc.stub_chain(:hmodifications).and_return(hmodifications)
        project.stub(:namespaces).and_return('project_namespaces')
      end

      context 'when span present' do
        it '' do
          expect( doc.hannotations(nil, span)[:tracks][0] ).to eql({
            project: project.name, denotations: hdenotations, relations: hrelations, modifications: hmodifications, namespaces: project.namespaces})
        end
      end

      context 'when track[:denotations] present' do
        it 'should add track to tracks' do
          expect( doc.hannotations(nil, nil)[:tracks][0] ).to eql({
            project: project.name, denotations: hdenotations, relations: hrelations, modifications: hmodifications, namespaces: project.namespaces})
        end
      end

      context 'when track[:denotations] nil' do
        before do
          doc.stub(:hdenotations).and_return([])
        end

        it 'should not add track to tracks' do
          expect( doc.hannotations(nil, nil)[:traks]).to be_blank
        end
      end
    end
  end

  describe 'destroy_project_annotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotation = FactoryGirl.create(:denotation, :doc => @doc)
      @modification_1 = FactoryGirl.create(:modification, :hid => 'M1', :obj => @denotation, :project => @project)
      @relation_1 = FactoryGirl.create(:subcatrel, :hid => 'r1', :obj => @denotation, :subj => @denotation, :project => @project)
      @relation_2 = FactoryGirl.create(:subinsrel, :hid => 'r2', :obj => @denotation, :project => @project)
      @modification_2 = FactoryGirl.create(:modification, :hid => 'M2', :obj => @relation_1, :obj_type => @relation_1.class.to_s, :project => @project)
      @modification_3 = FactoryGirl.create(:modification, :hid => 'M3', :obj => @relation_2, :obj_type => @relation_2.class.to_s, :project => @project)
      @project.reload
    end

    context 'when project present' do
      it 'should call destroy_all' do
        denotations = double(:denotations)
        denotations.stub(:destroy_all).and_return(nil)
        @doc.stub_chain(:denotations, :where).and_return(denotations)
        denotations.should_receive(:destroy_all)
        @doc.destroy_project_annotations(@project) 
      end

      it 'should reset project.annotations_count' do
        expect{ 
          @doc.destroy_project_annotations(@project) 
          @project.reload
        }.to change{ @project.annotations_count }.from(6).to(0)
      end
    end
  end


  describe 'to_hash' do
    before do
      # DO NOT INDENT
      @doc = FactoryGirl.create(:doc, sourcedb: 'sdb', sourceid: 'sdi', serial: 0, section: 'section', source: 'http://to.to', body: 'A
B')
    end

    it 'should return converted hash' do
      expect(@doc.to_hash).to eql({text: 'AB', sourcedb: @doc.sourcedb, sourceid: @doc.sourceid, divid: @doc.serial, section: @doc.section, source_url: @doc.source})
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

  describe 'self.has_divs?' do
    let(:doc) { FactoryGirl.create(:doc, sourcedb: "sdb", sourceid: 'sourceid_1') }

    context 'when doc has_divs? is true' do
      before do
        Doc.stub(:find_by_sourcedb_and_sourceid).and_return(doc)
        doc.stub(:has_divs?).and_return(true)
      end

      it 'should return true' do
        expect( Doc.has_divs?(doc.sourcedb, doc.sourceid) ).to be_true
      end
    end

    context 'when doc has_divs? is false' do
      before do
        Doc.stub(:find_by_sourcedb_and_sourceid).and_return(doc)
        doc.stub(:has_divs?).and_return(false)
      end

      it 'should return true' do
        expect( Doc.has_divs?(doc.sourcedb, doc.sourceid) ).to be_false
      end
    end
  end


  describe 'has_divs?' do
    let(:doc) { FactoryGirl.create(:doc, sourcedb: "sdb") }

    context 'when divs present' do
      before do
        doc.stub(:divs).and_return(true)
      end

      it 'should return true' do
        expect( doc.has_divs? ).to be_true
      end
    end

    context 'when divs not present' do
      before do
        doc.stub(:divs).and_return(false)
      end

      it 'should return false' do
        expect( doc.has_divs? ).to be_false
      end
    end
  end

  describe 'self.get_div_ids' do
    let(:doc) { FactoryGirl.create(:doc, sourcedb: "sdb", sourceid: 'sid') }
    let(:div_1) { FactoryGirl.create(:div, doc: doc) }
    let(:div_2) { FactoryGirl.create(:div, doc: doc) }

    before do
      doc.stub(:divs).and_return([div_1, div_2])
    end

    it 'should return same_sourcedb_sourceid serials map' do
      expect(Doc.get_div_ids(doc.sourcedb, doc.sourceid)).to match_array([div_1.serial, div_2.serial])
    end
  end

  describe 'attach_sourcedb_suffix' do
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
          @doc.sourcedb.should eql("#{@sourcedb}:#{@username}")
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

  describe 'expire_page_cache' do
    context 'when after_save' do
      it 'should call expire_page_cache' do
        @doc = FactoryGirl.build(:doc)
        @doc.should_receive(:expire_page_cache)
        @doc.save
      end
    end

    context 'when after_destroy' do
      it 'should call expire_page_cache' do
        @doc = FactoryGirl.create(:doc)
        @doc.should_receive(:expire_page_cache)
        @doc.destroy
      end
    end
  end

  describe 'decrement_docs_counter' do
    let(:doc) { FactoryGirl.create(:doc, body: '12345678901234567890') }
    let(:project) { double(:project) }

    before do
      doc.stub(:projects).and_return([project])
    end

    it 'should call decrement_docs_counter' do
      expect(project).to receive(:decrement_docs_counter).with(doc)
      doc.decrement_docs_counter
    end
  end  
   
  describe 'decrement_docs_counter' do
    before do
      @project_pmdocs_count = 1
      @project_pmcdocs_count = 2
      @project =             FactoryGirl.create(:project, user: FactoryGirl.create(:user), :pmdocs_count => @project_pmdocs_count, :pmcdocs_count => @project_pmcdocs_count)
      @associate_project_1 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_1_pmdocs_count = 3
      @i = 1
      @associate_project_1_pmdocs_count.times do
        @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s)
        @i += 1 
      end
      @associate_project_1_pmcdocs_count = 3
      @div = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @i.to_s)
      @i += 1 
      @associate_project_1_pmcdocs_count.times do
        @associate_project_1.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @i.to_s) 
        @i += 1 
      end     
      # @associate_project_1.pmcdocs_count 3 => 4
      @associate_project_1.docs << @div
      @associate_project_1.reload
      
      @associate_project_2 = FactoryGirl.create(:project, user: FactoryGirl.create(:user), :pmdocs_count => 0, :pmcdocs_count => 0)
      @associate_project_2_pmdocs_count = 4
      @associate_project_2_pmdocs_count.times do
        @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s) 
        @i += 1 
      end
      @associate_project_2_pmcdocs_count = 6
      @doc = FactoryGirl.create(:doc, :sourcedb => 'PubMed', :sourceid => @i.to_s)
      @i += 1 
      @associate_project_2_pmcdocs_count.times do
        @associate_project_2.docs << FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => @i.to_s) 
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

  describe 'get_annotations' do
    let(:doc) { FactoryGirl.create(:doc) }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:span) { double(:span) }
    let(:hdenotations) { double(:hdenotations) }
    let(:hrelations) { double(:hrelations) }
    let(:hmodifications) { double(:hmodifications) }
    let(:transform_denotations) { 'transform_denotations' }

    before do
      doc.stub(:hdenotations).and_return(hdenotations)
      doc.stub(:hrelations).and_return(hrelations)
      doc.stub(:hmodifications).and_return(hmodifications)
      TextAlignment::TextAlignment.stub_chain(:new, :transform_denotations).and_return(transform_denotations)
    end

    context 'options = nil' do
      before do
        @annotations = doc.get_annotations(span, project)
      end

      it 'should return project.name as :project' do
        expect(@annotations[:project]).to eql(project.name)
      end

      it 'should return self.sourcedb as :sourcedb' do
        expect(@annotations[:sourcedb]).to eql(doc.sourcedb)
      end

      it 'should return self.sourceid as :sourceid' do
        expect(@annotations[:sourceid]).to eql(doc.sourceid)
      end

      it 'should return self.serial as :divid' do
        expect(@annotations[:divid]).to eql(doc.serial)
      end

      it 'should return self.section as :section' do
        expect(@annotations[:section]).to eql(doc.section)
      end

      it 'should return doc.body as :text' do
        expect(@annotations[:text]).to eql(doc.body)
      end

      it 'should return doc.hdenotations as :denotations' do
        expect(@annotations[:denotations]).to eql(hdenotations)
      end

      it 'should return doc.hrelations as :relations' do
        expect(@annotations[:relations]).to eql(hrelations)
      end

      it 'should return doc.hmodifications as :modifications' do
        expect(@annotations[:modifications]).to eql(hmodifications)
      end
    end

    context 'when options[:encoding] == ascii' do
      let(:get_ascii_text) { 'get_ascii_text' }

      before do
        doc.stub(:get_ascii_text).and_return(get_ascii_text)
        @annotations = doc.get_annotations(span, project, encoding: 'ascii')
      end

      it 'should return transform_denotations as :denotations' do
        expect(@annotations[:denotations]).to eql(transform_denotations)
      end

      it 'should return asciitext as :text' do
        expect(@annotations[:text]).to eql(get_ascii_text)
      end
    end

    context 'when options[:encoding] == ascii' do
      let(:bag_denotations) { double(:hdenotations) }
      let(:bag_relations) { double(:hrelations) }

      before do
        doc.stub(:bag_denotations).and_return([bag_denotations, bag_relations])
        @annotations = doc.get_annotations(span, project, discontinuous_annotation: 'bag')
      end

      it 'should return bag_denotations as :denotations' do
        expect(@annotations[:denotations]).to eql(bag_denotations)
      end

      it 'should return bag_relations as :relations' do
        expect(@annotations[:relations]).to eql(bag_relations)
      end
    end
  end
  
  describe 'dummy' do
    let(:repeat_times) { 1 }

    it 'should call create' do
      expect(Doc).to receive(:create)
      Doc.dummy(repeat_times)
    end
  end

  describe 'self.pmc_to_divs' do
    before(:all) do
      FactoryGirl.create(:doc, sourcedb: 'PubMed', sourceid: '123', serial: 0)
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @body_0 = "BV Latent Membrane Protein 1 Activates Akt, NFκB, and Stat3 in B Cell Lymphomas
Latent membrane protein 1 (LMP1) is the major oncoprotein of Epstein-Barr virus (EBV). In transgenic mice, LMP1 promotes increased lymphoma development by 12 mo of age. This study reveals that lymphoma develops in B-1a lymphocytes, a population that is associated with transformation in older mice. The lymphoma cells have deregulated cell cycle markers, and inhibitors of Akt, NFκB, and Stat3 block the enhanced viability of LMP1 transgenic lymphocytes and lymphoma cells in vitro. Lymphoma cells are independent of IL4/Stat6 signaling for survival and proliferation, but have constitutively activated Stat3 signaling. These same targets are also deregulated in wild-type B-1a lymphomas that arise spontaneously through age predisposition. These results suggest that Akt, NFκB, and Stat3 pathways may serve as effective targets in the treatment of EBV-associated B cell lymphomas."
      @body_1 = "Epstein-Barr virus (EBV) is a ubiquitous γ-herpesvirus that infects humans predominantly at an early age with greater than 90% of the adult population infected with EBV [1]. EBV is linked to the development of both B lymphocyte and epithelial cell malignancies, including Burkitt lymphoma, Hodgkin disease (HD), and nasopharyngeal carcinoma (NPC), and cancers linked to immunosuppression, including post-transplant lymphoma and AIDS-associated lymphomas [2,3]. In vitro infection of B lymphocytes with EBV induces permanent growth transformation, and this ability to affect cell growth regulation likely contributes to the development of cancer.
Many of the viral proteins expressed in transformed cells, including the EBV nuclear antigens and latent membrane proteins, have profound effects on cell growth regulation and are required for EBV latent infection and B cell transformation [1]. Latent membrane protein 1 (LMP1) is considered the major oncoprotein of EBV, as it transforms rodent fibroblasts to tumorigenicity in nude mice and is expressed in HD, NPC, and immunosuppression-associated tumors [4–8]. In B lymphocytes, LMP1 mimics CD40 signaling, and both LMP1 and CD40 are essential for EBV-mediated B cell transformation [9–11]. While CD40 interacts with CD40 ligand expressed on activated T cells to induce B cell activation and differentiation, LMP1 acts as a constitutive signal through ligand-independent oligomerization. LMP1 and CD40 interact with the same tumor necrosis factor receptor–associated factors (TRAFs) leading to activation of NFκB, c-Jun N terminal kinase (JNK), and p38 MAPK signaling pathways [12–16]. Activation of NFκB is required for EBV-induced B cell transformation and its inhibition rapidly results in cell death [17,18]. Recent studies indicate that LMP1 also activates phosphatidylinositol 3 kinase (PI3K)/Akt signaling and that this activation is required for LMP1-mediated transformation of rodent fibroblasts [5,19].
In vitro, primary B cells can be maintained by CD40 ligation in combination with IL4 treatment. In vivo, CD40 signaling is necessary for germinal center (GC) formation such that mice deficient for CD40 or CD40L are unable to form GCs in response to T cell–dependent antigens [20,21]. Both the membrane proximal and distal cytoplasmic regions of CD40 that bind TRAF6 and TRAFs2/3/5, respectively, are necessary for GC formation, but either region is sufficient to induce extrafollicular B cell differentiation and restore low affinity antibody production [22]. Functionally, LMP1 can rescue CD40-deficient mice and restore immunoglobulin (Ig) class switching, most likely because LMP1 recruits similar TRAF molecules, TRAFs 1/2/3/5 and TRAF6, through the C-terminal activation regions 1 and 2 domains, respectively. However, LMP1 is unable to restore affinity maturation and GC formation [23].
Several EBV transforming proteins have been studied in transgenic mouse models, however, only LMP1 induces tumor development when expressed under the control of the Ig heavy chain promoter and enhancer [24–26]. The LMP1 transgenic mice (IgLMP1) express LMP1 in B lymphocytes, and in mice older than 12 mo, lymphoma develops with increased incidence (40%–50%) compared to wild-type control mice (11%), suggesting that LMP1 contributes to tumor development [26]. The LMP1 lymphomas have rearranged Ig genes and have activated Akt, JNK, p38, and NFκB, with specific activation of the NFκB family member cRel [27].
In this study, the LMP1 transgenic lymphocytes and lymphomas were further characterized and their growth properties in vitro were determined. To obtain pure populations of malignant lymphocytes and to enable more detailed biochemical analyses, examples of primary lymphomas were inoculated and passaged in SCID mice. Interestingly, lymphoma development was restricted to B-1a lymphocytes, a self-replenishing population of cells that are prone to malignancy [28,29]. LMP1 transgenic lymphocytes had increased viability in vitro and viability was increased by the addition of IL4. In contrast, both LMP1-positive and -negative lymphoma cells were independent of IL4 co-stimulation for survival and proliferation in vitro with a complete absence of activated Stat6, the IL4 target. The lymphomas were also distinguished by constitutive activation of Stat3 and deregulation of the Rb cell cycle pathway. Inhibition of the PI3K/Akt, NFκB, and Stat3 signaling pathways blocked the enhanced growth of both LMP1 transgenic and malignant lymphocytes, suggesting that these pathways are required for their growth and survival. These appear to be the same targets that are deregulated in wild-type B-1a lymphomas that arise spontaneously through age predisposition. This study reveals that LMP1 promotes malignancy in cells with the inherent ability to proliferate and that the Akt, NFκB, and Stat3 signaling pathways are required for its growth stimulatory effects.
"
      @body_2 = "High Levels of LMP1 Expression Correlates with the Development of Lymphoma
LMP1 expression in IgLMP1 mice was directed to B cells under the control of the Ig heavy chain promoter and enhancer. It has previously been shown that in these transgenic mice, LMP1 expression was restricted to B220+ B cells with lymphoma detected in greatly enlarged spleens [23,26]. To investigate whether LMP1 expression contributes to lymphoma development, B cells were purified from splenocytes by positive selection using anti-CD19 MACS magnetic beads, and equivalent amounts of B cells were analyzed by immunoblotting. LMP1 was detectable in LMP1 transgenic B cells, but upon development of lymphoma, LMP1 expression was stronger in 5/7 lymphomas analyzed with concomitant appearance of degradation products (Figure 1A). To determine whether the higher level of LMP1 detected was due to an expansion of malignant lymphocytes, expression of LMP1 in the spleen was further evaluated by immunohistochemical staining. Immunohistochemistry analysis of spleen sections detected LMP1 in the plasma membrane of cells in both the follicular white pulp and circulating lymphocytes in the red pulp (Figure 1B). LMP1 expression was heterogeneous with strong LMP1 staining interspersed amongst a background of cells staining weakly for LMP1. Upon development to lymphoma, LMP1 expression was more abundantly detected with multiple foci of intense LMP1 staining. This demonstrates that the increased LMP1 detected by immunoblotting upon malignant progression reflects an increase in LMP1 expression and an accumulation of cells expressing high levels of LMP1. This correlation between high LMP1 expression and the development of lymphoma suggests that progression to lymphoma results from increased levels of LMP1."

      @pmc_serial_0 = FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '123', serial: 0, body: @body_0)
      @pmc_serial_1 = FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '123', serial: 1, body: @body_1)
      @pmc_serial_2 = FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '123', serial: 2, body: @body_2)

      # project
      FactoryGirl.create(:docs_project, project_id: @project.id, doc_id: @pmc_serial_0.id)
      FactoryGirl.create(:docs_project, project_id: @project.id, doc_id: @pmc_serial_1.id)
      FactoryGirl.create(:docs_project, project_id: @project.id, doc_id: @pmc_serial_2.id)

      # denotations
      denotation_0 = FactoryGirl.create(:denotation, doc: @pmc_serial_0, project: @project)
      denotation_1 = FactoryGirl.create(:denotation, doc: @pmc_serial_1, project: @project)
      denotation_2 = FactoryGirl.create(:denotation, doc: @pmc_serial_2, project: @project)

      # subcatrels
      relation_1 = FactoryGirl.create(:subcatrel, subj: denotation_0, obj: denotation_1, project: @project)
      relation_2 = FactoryGirl.create(:subcatrel, subj: denotation_1, obj: denotation_2, project: @project)
      relation_3 = FactoryGirl.create(:subcatrel, subj: denotation_2, obj: denotation_2, project: @project)

      # catmods
      FactoryGirl.create(:modification, obj: denotation_0, project: @project)
      FactoryGirl.create(:modification, obj: denotation_2, project: @project)

      FactoryGirl.create(:modification, obj: relation_1, obj_type: 'Relation', project: @project)
      FactoryGirl.create(:modification, obj: relation_2, obj_type: 'Relation', project: @project)
      Doc.pmc_to_divs 
      @pmc_serial_0.reload
    end

    it 'should create divs' do
      expect( @pmc_serial_0.divs.size ).to eql(3)
    end

    it 'should create divs match body' do
      div = @pmc_serial_0.divs.where(serial: 0).first
      expect( @pmc_serial_0.body[div.begin...div.end] ).to eql(@body_0 + "\n")
      div = @pmc_serial_0.divs.where(serial: 1).first
      expect( @pmc_serial_0.body[div.begin...div.end] ).to eql(@body_1)
      div = @pmc_serial_0.divs.where(serial: 2).first
      expect( @pmc_serial_0.body[div.begin...div.end] ).to eql(@body_2 + "\n")
    end

    it 'should add subcatrels' do
      expect( @pmc_serial_0.subcatrels.count ).to eql(3)
    end

    it 'should add catmods' do
      expect( @pmc_serial_0.catmods.count ).to eql(2)
    end

    it 'should add subcatrelmods' do
      expect( @pmc_serial_0.subcatrelmods.count ).to eql(2)
    end

    it 'should update project' do
      expect( @project.docs.count ).to eql(1)
      expect( DocsProject.count ).to eql(1)
    end

    it 'should update project' do
      expect( @pmc_serial_0.denotations_count ).to eql(3)
    end
  end
end
