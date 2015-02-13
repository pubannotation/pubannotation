# encoding: utf-8
require 'spec_helper'

describe Shared do
  describe 'save annotations' do
    before do
      @doc = FactoryGirl.create(:doc, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
    end

    context 'when denotations exist' do
      before do
        @relations = 'relations'
        @modification = 'modification'
        @annotations = {:denotations => 'denotations', :relations => @relations, :modifications => @modification}
        @aligned_denotations = 'aligned_denotations'
        Shared.stub(:align_denotations).and_return(@aligned_denotations)
        Shared.stub(:save_hdenotations) do |denotations, project, doc|
          @denotations = denotations
        end
        Shared.stub(:save_hrelations) do |relations, project, doc|
          @relations = relations
        end
        Shared.stub(:save_hmodifications) do |modifications, project, doc|
          @modifications = modifications
        end
        @result = Shared.save_annotations(@annotations, @project, @doc)
      end

      it 'should exec save_hdenotations' do
        @denotations.should eql(@aligned_denotations)
      end

      it 'should return aligned annotations' do
        @result.should eql({denotations: @aligned_denotations, relations: @relations, modifications: @modification, text: @doc[:body]})
      end
    end
    
    context 'denotations does not exists' do
      before do
        @annotations = {text:"doc body"}
        @result = Shared.save_annotations(@annotations, @project, @doc)
      end
      
      it 'should return nil' do
        @result.should eql({text:"doc body"})
      end
    end
  end
  
  describe 'save_hdenotations' do
    before do
      @doc = FactoryGirl.create(:doc, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @associate_project_denotations_count_1 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_denotations_count_1.docs << @doc
      @associate_project_denotations_count_1.reload
      @di = 1
      1.times do
        FactoryGirl.create(:denotation, :begin => @di, :project_id => @associate_project_denotations_count_1.id, :doc_id => @doc.id)
        @di += 1
      end
      @associate_project_denotations_count_1.reload
      @doc_2 = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '12', :serial => 1, :section => 'section', :body => 'doc body')
      @associate_project_denotations_count_2 = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :denotations_count => 0)
      @associate_project_denotations_count_2.docs << @doc_2
      @associate_project_denotations_count_2.reload
      2.times do
        FactoryGirl.create(:denotation, :begin => @di, :project_id => @associate_project_denotations_count_2.id, :doc_id => @doc_2.id)
        @di += 1
      end
      @associate_project_denotations_count_2.reload
      @project.associate_projects << @associate_project_denotations_count_1
      @project.associate_projects << @associate_project_denotations_count_2
      
      @hdenotation = {:id => 'hid', :span => {:begin => 1, :end => 10}, :obj => 'Category'}
      @hdenotations = Array.new
      @hdenotations << @hdenotation
      @result = Shared.save_hdenotations(@hdenotations, @associate_project_denotations_count_1, @doc) 
      @denotation = Denotation.find_by_hid(@hdenotation[:id])
    end
    
    it 'should save successfully' do
      @result.should be_true
    end
    
    it 'should save hdenotation[:id] as hid' do
      @denotation.hid.should eql(@hdenotation[:id])
    end
    
    it 'should save hdenotation[:span][:begin] as begin' do
      @denotation.begin.should eql(@hdenotation[:span][:begin])
    end
    
    it 'should save hdenotation[:span][:end] as end' do
      @denotation.end.should eql(@hdenotation[:span][:end])
    end
    
    it 'should save hdenotation[:obj] as obj' do
      @denotation.obj.should eql(@hdenotation[:obj])
    end

    it 'should save project.id as project_id' do
      @denotation.project_id.should eql(@associate_project_denotations_count_1.id)
    end

    it 'should save doc.id as doc_id' do
      @denotation.doc_id.should eql(@doc.id)
    end
    
    it 'should project.denotations_count should equal 0 before save' do
      @project.denotations_count.should eql(0)
    end

    it 'should incliment project.denotations_count after denotation saved' do
      @project.reload
      @project.denotations_count.should eql((@associate_project_denotations_count_1.denotations_count + @associate_project_denotations_count_2.denotations_count) *2  + 1)
    end
      
    it 'associate_projectproject.denotations_count should equal 1 before save' do
      @associate_project_denotations_count_1.denotations_count.should eql(1)
    end
    
    it 'associate_projectproject.denotations_count should incremented after save' do
      @associate_project_denotations_count_1.reload
      @associate_project_denotations_count_1.denotations_count.should eql(2)
    end
    
    it 'associate_projectproject.denotations_count should remain' do
      @associate_project_denotations_count_2.reload
      @associate_project_denotations_count_2.denotations_count.should eql(2)
    end
  end
  
  describe 'save_hrelations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
      @hrelations = Array.new
    end
    
    describe 'before exec' do
      it 'Modification is empty' do
        Modification.all.should be_blank
      end
    end

    describe 'after exec' do
      before do
        @hrelation = {:id => 'hid', :pred => 'pred', :subj => @denotation.hid, :obj => @denotation.hid}
        @hrelations << @hrelation
        @result = Shared.save_hrelations(@hrelations, @project, @doc)
      end

      it '' do
        Relation.where(
          :hid => @hrelation[:id], 
          :pred => @hrelation[:pred], 
          :subj_id => @denotation.id, 
          :subj_type => @denotation.class, 
          :obj_id => @denotation.id, 
          :obj_type => @denotation.class, 
          :project_id => @project.id
        ).should be_present
      end
    end
  end
  
  describe 'save_hmodifications' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
    end
    
    context 'when hmodifications[:obj] match /^R/' do
      before do
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @subcatrel = FactoryGirl.create(:subcatrel, :obj => @denotation, subj: @denotation, :project => @project)
        @hmodification = {:id => 'hid', :pred => 'type', :obj => @subcatrel.hid}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = Shared.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.instances' do
        Modification.where(
          :hid => @hmodification[:id],
          :pred => @hmodification[:pred],
          :obj_id => @subcatrel.id,
          :obj_type => @subcatrel.class
        ).should be_present
      end
    end

    context 'when hmodifications[:obj] not match /^R/' do
      before do
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @hmodification = {:id => 'hid', :pred => 'type', :obj => @denotation.hid}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = Shared.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.instances' do
        Modification.where(
          :hid => @hmodification[:id],
          :pred => @hmodification[:pred],
          :obj_id => @denotation.id,
          :obj_type => @denotation.class
        ).should be_present
      end
    end
  end
  
  describe 'align_denotations' do
    context 'when denotations is nil' do
      before do
        @result = Shared.align_denotations(nil, '', '')
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
    
    context 'when canann exists' do
      before do
        @begin = 1
        @end = 5
        @denotation = {:span => {:begin => @begin, :end => @end}}
        @denotations = Array.new
        @denotations << @denotation
        @result = Shared.align_denotations(@denotations, 'from text', 'end of text')
      end
      
      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end

  describe 'store_annotations' do
    before do
      @text = 'text about'
      @denotations = [{"span" => {"begin" => 0, "end" => 134}, "obj" => "TOP"}, {"span" => {"begin" => 0, "end" => 134}, "obj" => "TITLE"}]
      @relations = nil
      @modifications = nil
      @annotations = {:text => @text, 
                      :denotations => @denotations, 
                      :relations => @relations, 
                      :modifications => @modifications}
      user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: user)
      Shared.stub(:save_annotations).and_return(nil)
    end

    context 'when options[:delayed] == true' do
      before do
        @options = {mode: 'mode', delayed: true}
      end

      context 'when finished without errors' do
        context 'when divs.length == 1' do
          before do
            @div = FactoryGirl.create(:doc)
            @divs = [@div]
          end

          it 'should call Shared.save_annotations with annotations, project, divs[0] and options' do
            Shared.should_receive(:save_annotations).with(@annotations, @project, @div, @options) 
            Shared.store_annotations(@annotations, @project, @divs, @options)
          end

          it 'should create project.notices with successful: true, method store_annotations' do
            @project.notices.should_receive(:create).with({successful: true, method: 'store_annotations'})
            Shared.store_annotations(@annotations, @project, @divs, @options)
          end
        end

        context 'when divs.length !== 1' do
          before do
            @div_1 = FactoryGirl.create(:doc)
            @div_2 = FactoryGirl.create(:doc)
            @divs = [@div_1, @div_2]
            @denotations = [{span: {begin: 3, end: 5}}]
            @annotations = {:text => @text, 
                            :denotations => @denotations, 
                            :relations => @relations, 
                            :modifications => @modifications}
            @find_divisions = [[1, [0, 3]], [1, [2, 5]]]
            TextAlignment.stub(:find_divisions).and_return(@find_divisions)
          end

          it 'should call Shared.save_annotations with annotations, project, divs[0]' do
            Shared.should_receive(:save_annotations).twice
            Shared.store_annotations(@annotations, @project, @divs, @options)
          end

          it 'should create project.notices with successful: true, method store_annotations' do
            @project.notices.should_receive(:create).with({successful: true, method: 'store_annotations'})
            Shared.store_annotations(@annotations, @project, @divs, @options)
          end
        end
      end

      context 'when finished without errors' do
        it 'should create project.notices with successful: false, method store_annotations' do
          @project.notices.should_receive(:create).with({successful: false, method: 'store_annotations'})
          Shared.store_annotations(@annotations, @project, nil, @options)
        end
      end
    end

    context 'when options[:delayed] == false' do
      before do
        @options = {mode: 'mode'}
        @div = FactoryGirl.create(:doc)
        @divs = [@div]
      end

      it 'should not create project.notices with successful: true, method store_annotations' do
        @project.notices.should_not_receive(:create).with({successful: true, method: 'store_annotations'})
        Shared.store_annotations(@annotations, @project, @divs, @options)
      end
    end
  end
end
