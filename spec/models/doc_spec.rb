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
      @project_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @project_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      FactoryGirl.create(:docs_project, :project_id => @project_1.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => @doc_1.id)
      FactoryGirl.create(:docs_project, :project_id => @project_2.id, :doc_id => FactoryGirl.create(:doc).id)
      @doc_1.reload
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
    before(:all) do
      Doc.delete_all
      @pmdocs_count = 3
      @pmdocs_count.times do |time|
        FactoryGirl.create(:doc, :sourcedb => 'PubMed', serial: time + 1)
      end
      @not_pmdoc = FactoryGirl.create(:doc, :sourcedb => 'PMC')
      @pmdocs = Doc.pmdocs
    end

    it 'should match doc where sourcedb == PubMed size ' do
      @pmdocs.size.should eql(@pmdocs_count)
    end

    it 'should not include document where sourcedb != PubMed' do
      @pmdocs.should_not include(@not_pmdoc)
    end
  end

  describe 'scope pmcdocs' do
    before(:all) do
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
    before do
      Doc.delete_all
      # has 1 relations
      @doc_1 = FactoryGirl.create(:doc) 
      @denotation_doc_1_1 = FactoryGirl.create(:denotation, doc_id: @doc_1.id)
      @relation_denotation_1 = FactoryGirl.create(:relation, subj_id: @denotation_doc_1_1.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)

      # has 3 relations
      @doc_2 = FactoryGirl.create(:doc) 
      @denotation_doc_2_1 = FactoryGirl.create(:denotation, doc_id: @doc_2.id)
      @relation_denotation_2 = FactoryGirl.create(:relation, subj_id: @denotation_doc_2_1.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @denotation_doc_2_2 = FactoryGirl.create(:denotation, doc_id: @doc_2.id)
      @relation_denotation_3 = FactoryGirl.create(:relation, subj_id: @denotation_doc_2_2.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @denotation_doc_2_3 = FactoryGirl.create(:denotation, doc_id: @doc_2.id)
      @relation_denotation_4 = FactoryGirl.create(:relation, subj_id: @denotation_doc_2_3.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)

      # has 4 relations
      @doc_3 = FactoryGirl.create(:doc) 
      @denotation_doc_3_1 = FactoryGirl.create(:denotation, doc_id: @doc_3.id)
      @relation_denotation_5 = FactoryGirl.create(:relation, subj_id: @denotation_doc_3_1.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @denotation_doc_3_2 = FactoryGirl.create(:denotation, doc_id: @doc_3.id)
      @relation_denotation_6 = FactoryGirl.create(:relation, subj_id: @denotation_doc_3_2.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @relation_denotation_7 = FactoryGirl.create(:relation, subj_id: @denotation_doc_3_2.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @relation_denotation_8 = FactoryGirl.create(:relation, subj_id: @denotation_doc_3_2.id, subj_type: 'Annotation', obj: @denotation_doc_1_1)
      @doc_4 = FactoryGirl.create(:doc) 
      @denotation_doc_1_1.reload
      @denotation_doc_2_1.reload
      @denotation_doc_2_2.reload
      @denotation_doc_2_3.reload
      @denotation_doc_3_1.reload
      @denotation_doc_3_2.reload
      @doc_1.reload
      @doc_2.reload
      @doc_3.reload
      @doc_4.reload
    end

    # has 0 relations

    it 'should order Docs by count of relations' do
      expect( Doc.relations_count.first ).to eql(@doc_3)
      expect( Doc.relations_count.second ).to eql(@doc_2)
      expect( Doc.relations_count.last ).to eql(@doc_4)
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
    before do
      @user = FactoryGirl.create(:user) 
      @current_user = FactoryGirl.create(:user) 
      @doc_1 = FactoryGirl.create(:doc) 
      @doc_2 = FactoryGirl.create(:doc) 
      @doc_3 = FactoryGirl.create(:doc) 
      @doc_4 = FactoryGirl.create(:doc) 
      @project_accessibility_0_user = FactoryGirl.create(:project, accessibility: 0, user: @user) 
      @docs_project_1 = FactoryGirl.create(:docs_project, doc_id: @doc_1.id, project_id: @project_accessibility_0_user.id) 
      @project_accessibility_1_user = FactoryGirl.create(:project, accessibility: 1, user: @user) 
      @docs_project_2 = FactoryGirl.create(:docs_project, doc_id: @doc_2.id, project_id: @project_accessibility_1_user.id) 
      @project_accessibility_0_currrent_user = FactoryGirl.create(:project, accessibility: 0, user: @current_user) 
      @docs_project_3 = FactoryGirl.create(:docs_project, doc_id: @doc_3.id, project_id: @project_accessibility_0_currrent_user.id) 
      @project_accessibility_1_currrent_user = FactoryGirl.create(:project, accessibility: 1, user: @current_user) 
      @docs_project_4 = FactoryGirl.create(:docs_project, doc_id: @doc_4.id, project_id: @project_accessibility_1_currrent_user.id) 
    end

    it 'should include project.accessibility == 1 OR user_id == current_user.id' do
      expect( Doc.accessible_projects(@current_user) ).to include(@doc_2)
      expect( Doc.accessible_projects(@current_user) ).to include(@doc_3)
      expect( Doc.accessible_projects(@current_user) ).to include(@doc_4)
    end
  end

  describe 'scope sql' do
    let(:doc_1) { FactoryGirl.create(:doc) } 
    let(:doc_2) { FactoryGirl.create(:doc) } 
    let(:doc_3) { FactoryGirl.create(:doc) } 

    it 'should return docs id included in array and order by id asc' do
      expect( Doc.sql([doc_1.id, doc_2.id, doc_3.id]).first ).to eql(doc_1)
      expect( Doc.sql([doc_1.id, doc_2.id, doc_3.id]).last ).to eql(doc_3)
    end
  end

  describe 'same_sourcedb_sourceid' do
    let!(:doc_sourcedb_pmc_sourceid_1_1) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '1') } 
    let!(:doc_sourcedb_pmc_sourceid_1_2) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '1') } 
    let!(:doc_sourcedb_pmc_sourceid_2_1) { FactoryGirl.create(:doc, sourcedb: 'PMC', sourceid: '2') } 
    let!(:doc_sourcedb_pdc_sourceid_2_1) { FactoryGirl.create(:doc, sourcedb: 'PDC', sourceid: '1') } 

    it 'should return same sourcedb and sourceid docs' do
      expect( Doc.same_sourcedb_sourceid('PMC', '1').collect{|d| d.sourcedb}.uniq ).to match_array([ 'PMC' ])
      expect( Doc.same_sourcedb_sourceid('PMC', '1').collect{|d| d.sourceid}.uniq ).to match_array([ '1' ])
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
      expect( @docs.select{|doc| doc.sourcedb == nil || doc.sourcedb == ''} ).to be_blank
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
      Doc.delete_all
      @doc_1 = FactoryGirl.create(:doc, body: 'doc_1')
      @doc_2 = FactoryGirl.create(:doc, body: 'doc_2')
      @doc_3 = FactoryGirl.create(:doc, body: 'doc_3')
      @docs  = Doc.sort_by_params([['id DESC']])
    end

    context 'when sort_order is id DESC' do

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

  describe 'scope diff' do
    let(:created_2hours_ago) { FactoryGirl.create(:doc, created_at: 2.hours.ago)}
    let(:created_30minutes_ago){ FactoryGirl.create(:doc, created_at: 30.minutes.ago)}

    it 'should not inclde created before specific hour ago' do
      expect(Doc.diff).not_to include(created_2hours_ago)
    end

    it 'should inclde created after specific hour ago' do
      expect(Doc.diff).to include(created_30minutes_ago)
    end
  end

  describe 'search_docs' do
    let(:sourcedb) { 'sdb' }
    let(:sourceid) { '123456' }
    let(:body) { 'body' }
    let(:doc_1) { FactoryGirl.create(:doc, sourceid: sourceid, sourcedb: sourcedb, body: body) }
    let(:total) { 'total' }
    let(:docs) { 'docs' }
    let(:search_size) { 5 }

    before do
      Doc.stub_chain(:search, :results, :total).and_return(total)
      Doc.stub_chain(:search, :records, :order).and_return(docs)
      stub_const('Doc::SEARCH_SIZE', search_size)
    end

    context 'when params sourcedb, sourceid and body present' do
      it 'should return search results and records with hash' do
        expect(Doc.search_docs({sourcedb: sourcedb, sourceid: sourceid, body: body})).to eql({total: total, docs: docs})
        
      end

      it 'should search with sourcedb, sourceid and body' do
        expect(Doc).to receive(:search).with(
          {query: 
           {bool: 
            {must: nil, 
             should: [
               {match: {sourcedb: {query: sourcedb, fuzziness: 0}}}, 
               {match: {sourceid: {query: sourceid, fuzziness: 0}}}, 
               {match: {body: {query: body, fuzziness: "AUTO"}}}], 
             minimum_should_match: 3}}, size: search_size}
        )
        Doc.search_docs({sourcedb: sourcedb, sourceid: sourceid, body: body})
      end
    end

    context 'when params sourcedb, sourceid and body nil' do
      it 'should search without attributes' do
        expect(Doc).to receive(:search).with(
          {query: 
           {bool: 
            {must: nil, 
             should: [
               {match: {sourcedb: {query: nil, fuzziness: 0}}}, 
               {match: {sourceid: {query: nil, fuzziness: 0}}}, 
               {match: {body: {query: nil, fuzziness: "AUTO"}}}], 
             minimum_should_match: 0}}, size: search_size}
        )
        Doc.search_docs({})
      end
    end

    context 'when project_id present' do
      let(:project_id) { 1 }
      it 'should search with project_id' do
        expect(Doc).to receive(:search).with(
          {query: 
           {bool: 
            {must: [{match: {"projects.id"=>1}}], 
             should: [
               {match: {sourcedb: {query: nil, fuzziness: 0}}}, 
               {match: {sourceid: {query: nil, fuzziness: 0}}}, 
               {match: {body: {query: nil, fuzziness: "AUTO"}}}], 
             minimum_should_match: 0}}, size: search_size}
        )
        Doc.search_docs({project_id: project_id})
      end
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

  describe 'get_divs' do
    let(:sourcedb) { 'sdb' }
    let(:sourceid) { '123456' }
    let(:divid) { 'divid' }

    context 'when docspec sourcedb sourceid present' do
      context 'when div_id present' do
        it 'should call find_al_by_sourcedb_and_sourceid_and_serial' do
          expect(Doc).to receive(:find_all_by_sourcedb_and_sourceid_and_serial)#.with(sourcedb, sourceid, divid)
          Doc.get_divs({sourcedb: sourcedb, sourceid: sourceid, div_id: divid })
        end
      end

      context 'when divid nil' do
        it 'should call find_all_by_sourcedb_and_sourceid' do
          expect(Doc).to receive(:find_all_by_sourcedb_and_sourceid).with(sourcedb, sourceid)
          Doc.get_divs({sourcedb: sourcedb, sourceid: sourceid})
        end
      end
    end

    context 'when docspec sourcedb sourceid nil' do
      it 'should return nil' do
        expect( Doc.get_divs({}) ).to be_blank
      end
    end
  end

  describe 'exist?' do
    let(:doc) { FactoryGirl.create(:doc) }

    context 'when get_doc is not nil' do
      before do
        doc.stub(:get_doc).and_return([])
      end

      it 'should return true' do
        expect(doc.get_doc).to be_true
      end
    end

    context 'when get_doc is nil' do
      before do
        doc.stub(:get_doc).and_return(nil)
      end

      it 'should return false' do
        expect(doc.get_doc).to be_false
      end
    end
  end

  describe 'import_from_sequence', elasticsearch: true do
    let(:divs) { [{body: 'b', heading: 'heading'}] }
    let(:doc_sequence) { double(:doc_sequence, divs: divs, source_url: 'src')}

    before do
      divs.stub(:source_url).and_return('src')
      Object.stub_chain(:const_get, :new).and_return(doc_sequence)
      Doc.stub(:index_diff).and_return(nil)
    end

    context 'when sourcedb is nil' do
      it 'should raise ArgumentError' do
        expect{ Doc.import_from_sequence(nil, '123456') }.to raise_error(ArgumentError)
      end
    end

    context 'when sourceid is nil' do
      it 'should raise ArgumentError' do
        expect{ Doc.import_from_sequence('sourcedb', nil) }.to raise_error(ArgumentError)
      end
    end   

    describe 'doc_sequence' do
      context 'when successful' do
        let(:sourcedb) { 'sourcedb' }
        let(:sourceid) { 'sourceid' }

        before do
          Doc.any_instance.stub(:save).and_return(true)
        end

        it 'should call index_diff' do
          expect(Doc).to receive(:index_diff)
          Doc.import_from_sequence('sdb', sourceid)
        end

        it 'should return divs' do
          expect( Doc.import_from_sequence(sourcedb, sourceid) ).to be_present
        end

        it 'should call index_diff' do
          expect(Doc).to receive(:new).with({body: divs[0][:body], section: divs[0][:heading], source: doc_sequence.source_url, sourcedb: sourcedb, sourceid: sourceid, serial: 0})
          NilClass.any_instance.stub(:save).and_return(true)
          Doc.import_from_sequence(sourcedb, sourceid)
        end
      end
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
      context 'denotations_count' do
        let(:docs) { double(:docs) }
        let(:denotations_count) { double(:denotations_count) }

        before do
          docs.stub(:denotations_count).and_return(denotations_count)
        end

        it 'should return docs.denotations_count' do
          expect(Doc.order_by(docs, 'denotations_count')).to eql(denotations_count)
        end
      end

      context 'same_sourceid_denotations_count' do
        context 'when docs.first.sourcedb = PubMed' do
          let( :pubmed_count_1 ) { FactoryGirl.create(:doc, sourceid: 1.to_s, sourcedb: 'PubMed', denotations_count: 1) }
          let( :pubmed_count_2 ) { FactoryGirl.create(:doc, sourceid: 2.to_s, sourcedb: 'PubMed', denotations_count: 2) }
          let( :pubmed_count_3 ) { FactoryGirl.create(:doc, sourceid: 3.to_s, sourcedb: 'PubMed', denotations_count: 3) }
          let( :pubmed_count_0 ) { FactoryGirl.create(:doc, sourceid: 1.to_s, sourcedb: 'PubMed', denotations_count: 0) }

          before do
            pubmed_count_0
            pubmed_count_1
            pubmed_count_2
            pubmed_count_3
            @docs = Doc.order_by(Doc.where('id IN (?)', [pubmed_count_0.id, pubmed_count_1.id, pubmed_count_2.id, pubmed_count_3.id]), 'same_sourceid_denotations_count')
          end

          it 'should order by denotations_count' do
            expect(@docs.first.denotations_count).to eql(3)
            expect(@docs.last.denotations_count).to eql(0)
          end
        end

        context 'when docs.first.sourcedb != PubMed' do
          let(:pmc_count_1) {  double(:doc, same_sourceid_denotations_count: 1, sourcedb: 'PMC') }
          let(:pmc_count_2) {  double(:doc, same_sourceid_denotations_count: 2, sourcedb: 'PMC') }
          let(:pmc_count_3) {  double(:doc, same_sourceid_denotations_count: 3, sourcedb: 'PMC') }

          before do
            docs = [pmc_count_1, pmc_count_2, pmc_count_3]
            @docs = Doc.order_by(docs, 'same_sourceid_denotations_count')
          end
          
          it 'docs.first should most same_sourceid_denotations_count' do
            @docs[0].should eql(pmc_count_3)
            @docs[1].should eql(pmc_count_2)
            @docs.last.should eql(pmc_count_1)
          end
        end
      end

      context 'relations_count' do
        let(:relations_count) { double(:relations_count) }
        let(:docs) { Doc }

        before do
          Doc.stub(:relations_count).and_return(relations_count)
        end

        it 'should requturn docs.relations_count' do
          expect( Doc.order_by(docs, 'relations_count') ).to eql(relations_count)
        end
      end

      context 'same_sourceid_relations_count' do
        context 'when docs.first.sourcedb == PubMed' do
          before(:all) do
            Doc.delete_all
            @count_1 = FactoryGirl.create(:doc, sourcedb: 'PubMed', subcatrels_count: 1)
            @count_2 = FactoryGirl.create(:doc, sourcedb: 'PubMed', subcatrels_count: 2)
            @count_3 = FactoryGirl.create(:doc, sourcedb: 'PubMed', subcatrels_count: 3)
            @docs = Doc.order_by(Doc.where('id > ?', 0), 'same_sourceid_relations_count')
          end

          it 'docs.first should most same_sourceid_denotations_count' do
            @docs[0].should eql(@count_3)
            @docs[1].should eql(@count_2)
            @docs.last.should eql(@count_1)
          end
        end

        context 'when docs.first.sourcedb != PubMed' do
          let( :same_source_id_relations_count_1 ) { FactoryGirl.create(:doc, sourcedb: 'PMC') }
          let( :same_source_id_relations_count_2 ) { FactoryGirl.create(:doc, sourcedb: 'PMC') }
          let( :same_source_id_relations_count_3 ) { FactoryGirl.create(:doc, sourcedb: 'PMC') }

          before do
            same_source_id_relations_count_1.stub(:same_sourceid_relations_count).and_return(1)
            same_source_id_relations_count_2.stub(:same_sourceid_relations_count).and_return(2)
            same_source_id_relations_count_3.stub(:same_sourceid_relations_count).and_return(3)
            @docs = Doc.order_by([same_source_id_relations_count_1, same_source_id_relations_count_2, same_source_id_relations_count_3], 'same_sourceid_relations_count')
          end
          
          it 'doc which has 3 relations(same sourceid) should be docs[0]' do
            expect( @docs.first).to eql(same_source_id_relations_count_3)
            expect( @docs.last ).to eql(same_source_id_relations_count_1)
          end
        end
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
    let!(:pmc_denotations_count_1) { FactoryGirl.create(:doc, sourceid: 'PMC', denotations_count: 1) }
    let!(:pmc_denotations_count_2) { FactoryGirl.create(:doc, sourceid: 'PMC', denotations_count: 2) }
    let!(:pubmed_denotations_count_2) { FactoryGirl.create(:doc, sourceid: 'PubMed', denotations_count: 2) }

    it 'should return sum of same sourceid denotations_count' do
      expect(pmc_denotations_count_1.same_sourceid_denotations_count).to eql(3)
    end
  end

  describe 'same_sourceid_relations_count' do
    let!(:pmc_denotations_count_1) { FactoryGirl.create(:doc, sourceid: 'PMC', subcatrels_count: 1) }
    let!(:pmc_denotations_count_2) { FactoryGirl.create(:doc, sourceid: 'PMC', subcatrels_count: 2) }
    let!(:pubmed_denotations_count_2) { FactoryGirl.create(:doc, sourceid: 'PubMed', subcatrels_count: 2) }

    it 'should return sum of same sourceid subcatrels_count' do
      expect(pmc_denotations_count_1.same_sourceid_relations_count).to eql(3)
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
          pending '' do
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
          pending '' do
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
          pending '' do
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
          pending '' do
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
    let(:doc) { FactoryGirl.create(:doc) } 
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:self_project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
    let(:span) { 'span' }
    let(:hdenotations) { 'hdenotations' }

    before do
      FactoryGirl.create(:docs_project, doc_id: doc.id, project_id: self_project.id)
      doc.reload
      doc.stub(:hdenotations).and_return(hdenotations)
    end

    context 'when project present' do
      context 'when project respond_to each' do
        let(:projects) { [project] }

        it 'should set hdenotations' do
          expect(doc).to receive(:hdenotations).with(project, span)
          doc.denotations_in_tracks(projects, span)
        end

        it 'should project name and doc.hdenotations' do
          expect( doc.denotations_in_tracks(project, span) ).to eql([{project: project.name, denotations: hdenotations}])
        end
      end

      context 'when project not respond_to each' do
        it 'should set hdenotations' do
          expect(doc).to receive(:hdenotations).with(project, span)
          doc.denotations_in_tracks(project, span)
        end

        it 'should project name and doc.hdenotations' do
          expect( doc.denotations_in_tracks(project, span) ).to eql([{project: project.name, denotations: hdenotations}])
        end
      end
    end

    context 'when project nil' do
      it 'should self.project name and doc.hdenotations' do
        expect( doc.denotations_in_tracks(nil, span) ).to eql([{project: self_project.name, denotations: hdenotations}])
      end
    end
  end

  describe 'get_denotations_count' do
    let(:doc) { FactoryGirl.create(:doc, denotations_count: 5) }
    let(:project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }

    context 'when project.nil && span.nil' do
      it 'should return self.denotations_count' do
        expect( doc.get_denotations_count(nil, nil) ).to eql(doc.denotations_count)
      end
    end

    context 'when span.nil' do
      let(:denotations_from_projects_count) { 5 }

      before do
        doc.stub_chain(:denotations, :from_projects, :count).and_return(denotations_from_projects_count)
      end

      it 'should return self.denotations.from_projects.count' do
        expect( doc.get_denotations_count(project, nil) ).to eql(denotations_from_projects_count)
      end
    end

    context 'when project and span present' do
      let(:get_denotations_size) { 10 }
      let(:span) { 'span' }

      before do
        doc.stub_chain(:get_denotations, :size).and_return(get_denotations_size)
      end

      it 'should return self.get_denotations.size' do
        expect( doc ).to receive(:get_denotations).with(project, span)
        doc.get_denotations_count(project, span)
      end

      it 'should return self.get_denotations.size' do
        expect( doc.get_denotations_count(project, span) ).to eql(get_denotations_size)
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
  end

  describe 'destroy_project_annotations' do
    before do
      @doc = FactoryGirl.create(:doc)
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @denotations = double(:denotations)
      @denotations.stub(:destroy_all).and_return(nil)
      @doc.stub(:denotations).and_return(@denotations)
      @denotations.stub(:from_projects).and_return(@denotations)
    end

    context 'when project nil' do
      it 'should raise error' do
        expect{ @doc.destroy_project_annotations(nil) }.to raise_error
      end
    end

    context 'when project present' do
      it 'should call from_projects.destroy_all' do
        @denotations.should_receive(:from_projects)
        @denotations.should_receive(:destroy_all)
        @doc.destroy_project_annotations(@project) 
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
      @doc = FactoryGirl.create(:doc, sourcedb: 'sdb', sourceid: 'sdi', section: 'section', source: 'http://to.to', body: 'AB')
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
        expect( @doc.updatable_for?(@user)).to be_true
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

  describe 'create_doc', elasticsearch: true do
    before do
      @divs = [{body: 'body1', heading: 'heading_1'}]
      @attributes = {source_url: 'source_url', sourcedb: 'sourcedb', sourceid: 'sourceid'}
      Doc.stub(:index_diff).and_return(nil)
      Doc.stub(:divs_hash).and_return(nil)
      @doc = Doc.create_doc(@divs, @attributes)
    end

    it 'should create doc by divs_hash and attributes' do
      expect( @doc[0][:body] ).to eql(@divs[0][:body])
      expect( @doc[0][:section] ).to eql(@divs[0][:heading])
      expect( @doc[0][:source] ).to eql(@attributes[:source_url])
      expect( @doc[0][:sourcedb] ).to eql(@attributes[:sourcedb])
      expect( @doc[0][:sourceid] ).to eql(@attributes[:sourceid])
      expect( @doc[0][:serial] ).to eql(0)
    end

    it 'should call index_diff' do
      expect(Doc).to receive(:index_diff)
      Doc.create_doc(nil)
    end
  end

  describe 'create_divs' do
    describe 'assert method' do
      before do
        @divs = [{body: 'body1', heading: 'heading_1'}]
        @attributes = {source_url: 'source_url', sourcedb: 'sourcedb', sourceid: 'sourceid'}
        Doc.stub(:index_diff).and_return(nil)
        Doc.stub(:divs_hash).and_return(nil)
        @doc = Doc.create_divs(@divs, @attributes)
      end

      it 'should create doc by divs_hash and attributes' do
        expect( @doc[0][:body] ).to eql(@divs[0][:body])
        expect( @doc[0][:section] ).to eql(@divs[0][:heading])
        expect( @doc[0][:source] ).to eql(@attributes[:source_url])
        expect( @doc[0][:sourcedb] ).to eql(@attributes[:sourcedb])
        expect( @doc[0][:sourceid] ).to eql(@attributes[:sourceid])
        expect( @doc[0][:serial] ).to eql(0)
      end
    end

    describe 'elasticsearch', elasticsearch: true do
      it 'should call index_diff' do
        expect(Doc).to receive(:index_diff)
        Doc.create_divs(nil)
      end
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
      @doc = FactoryGirl.create(:doc)  
    end
    
    context 'when same sourcedb and sourceid doc blank' do
      before do
        Doc.stub_chain(:same_sourcedb_sourceid, :size).and_return(1)
      end

      it 'should return false' do
        @doc.has_divs?.should be_false
      end
    end
    
    context 'when same sourcedb and sourceid doc present' do
      before do
        Doc.stub_chain(:same_sourcedb_sourceid, :size).and_return(2)
      end
      
      it 'should return true' do
        @doc.has_divs?.should be_true
      end
    end
  end

  describe 'self.get_div_ids' do
    before do
      Doc.delete_all
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
    pending '' 'before_validation comennted' do
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

  describe 'expire_page_cache' do
    let(:actioncontroller_base) { double(:actioncontroller_base) }
    
    before do
      ActionController::Base.stub(:new).and_return(actioncontroller_base)
    end

    it 'should call expire_fragment' do
      expect( actioncontroller_base ).to receive(:expire_fragment).with('sourcedbs')
      Doc.new.expire_page_cache
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

  describe 'index_diff' do
    it 'should call Delayed::Job' do
      expect( Delayed::Job ).to receive(:enqueue).with(DelayedRake.new('elasticsearch:import:model', class: 'Doc', scope: 'diff'))
      Doc.index_diff
    end
  end

  describe 'dummy' do
    let(:repeat_times) { 1 }

    it 'should call create' do
      expect(Doc).to receive(:create)
      Doc.dummy(repeat_times)
    end
  end
end
