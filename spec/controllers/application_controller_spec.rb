# encoding: UTF-8
require 'spec_helper'

describe ApplicationController do
  controller do
    def after_sign_in_path_for_test(resource_or_scope)
      after_sign_out_path_for(resource_or_scope)
    end
  end
  
  describe 'after_sign_out_path' do
    before do
      @user = FactoryGirl.create(:user)
      @referrer = 'http://example.cop'
      controller.request.stub referrer: @referrer
    end
    
    it "should return.referrer" do
      controller.after_sign_in_path_for_test(@user).should eql(@referrer)
    end
  end
  
  describe 'get_docspec' do
    context 'pmdoc_id' do
      before do
        @params = {:pmdoc_id => 1}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return values which includes params[:pmdoc_id]' do
        @result.should eql(['PubMed', @params[:pmdoc_id], 0])
      end
    end

    context 'pmcdoc_id' do
      before do
        @params = {:pmcdoc_id => 1, :div_id => 2}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return values which includes params[:pmcdoc_id] and params[:div_id]' do
        @result.should eql(['PMC', @params[:pmcdoc_id], @params[:div_id]])
      end
    end

    context 'others' do
      before do
        @params = {}
        @result = controller.get_docspec(@params)
      end
      
      it 'should return nil array' do
        @result.should eql([nil, nil, nil])
      end
    end
  end
  
  describe 'get_project' do
    before do
      @user = FactoryGirl.create(:user)
    end

    context 'when ansset exists' do
      context 'and when project.accessibility == 1' do
        before do
          @current_user = FactoryGirl.create(:user)
          controller.stub(:user_signed_in?).and_return(false)
          @project = FactoryGirl.create(:project, :accessibility => 1, :user => @user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs project and nil' do
          @result.should eql([@project, nil])
        end
      end

      context 'and when project.accessibility !=1 and project.user == current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @project = FactoryGirl.create(:project, :accessibility => 2, :user => @current_user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs project and nil' do
          @result.should eql([@project, nil])
        end
      end

      context 'and when project.accessibility !=1 and project.user != current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @project = FactoryGirl.create(:project, :accessibility => 2, :user => @user, :name => 'Project Name')  
          @result = controller.get_project(@project.name)
        end
        
        it 'should returs nil and message which notice annotationset is private' do
          @result.should eql([nil, "The annotation set, #{@project.name}, is specified as private."])
        end
      end
    end
    
    context 'when ansset does not exists' do
      before do
        @result = controller.get_project('')
      end
      
      it 'returns nil and message notice annotasion set does not exist' do
        @result.should eql([nil, "The annotation set, , does not exist."])
      end
    end
  end
  
  describe 'get_projects' do
    before do
      @another_user = FactoryGirl.create(:user)
      @current_user = FactoryGirl.create(:user)
      @project_accessibility_1_and_another_user_project = FactoryGirl.create(:project, :user => @another_user, :accessibility => 1) 
      @project_accessibility_not_1_and_another_user_project = FactoryGirl.create(:project, :user => @another_user, :accessibility => 2) 
      @project_accessibility_1_and_current_user_project = FactoryGirl.create(:project, :user => @current_user, :accessibility => 1) 
      @project_accessibility_not_1_and_current_user_project = FactoryGirl.create(:project, :user => @current_user, :accessibility => 2) 
      current_user_stub(@current_user)
      @result = controller.get_projects()
    end
    
    it 'should include accessibility = 1 and another users project' do
      @result.should include(@project_accessibility_1_and_another_user_project)
    end
    
    it 'should not include accessibility != 1 and another users project' do
      @result.should_not include(@project_accessibility_not_1_and_another_user_project)
    end
    
    it 'should include accessibility = 1 and current users project' do
      @result.should include(@project_accessibility_1_and_current_user_project)
    end
    
    it 'should include accessibility != 1 and current users project' do
      @result.should include(@project_accessibility_not_1_and_current_user_project)
    end
  end
  
  describe 'get_doc' do
    context 'when doc exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1)
      end

      context 'and when project passed and doc.projects does not include project' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @result = controller.get_doc(@doc.sourcedb, @doc.sourceid, @doc.serial, @project)
        end
        
        it 'should return nil and message that doc does not belongs to the annotasion set' do
          @result.should eql([nil, "The document, #{@doc.sourcedb}:#{@doc.sourceid}, does not belong to the annotation set, #{@project.name}."])
        end
      end
      
      context 'and when project does not passed' do
        before do
          @result = controller.get_doc(@doc.sourcedb, @doc.sourceid, @doc.serial, nil)
        end
        
        it 'should return doc and nil' do
          @result.should eql([@doc, nil])
        end
      end
    end

    context 'when doc does not exists' do
      before do
        @result = controller.get_doc(nil, nil, nil, nil)
      end
      
      it 'should return nil and no annotation message' do
        @result.should eql([nil, "No annotation to the document, :, exists in PubAnnotation."])
      end
    end
  end
  
  describe 'get_divs' do
    context 'when divs present' do
      context 'and when project passed and divs.first.projects exclude project' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1)
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @result = controller.get_divs(@doc.sourceid, @project)
        end
        
        it 'should return nil and message doc does not belongs to the annotation' do
          @result.should eql([nil, "The document, PMC::#{@doc.sourceid}, does not belong to the annotation set, #{@project.name}."])
        end
      end

      context 'and when project does not passed' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1)
          @result = controller.get_divs(@doc.sourceid, nil)
        end
        
        it 'should return docs and nil' do
          @result.should eql([[@doc], nil])
        end
      end
    end

    context 'when divs is blank' do
      before do
        @result = controller.get_divs(nil, nil)
      end
      
      it 'should return nil and no annotation message' do
        @result.should eql([nil, "No annotation to the document, PMC:, exists in PubAnnotation."])
      end
    end
  end
  
  describe 'rewrite ascii' do
    before do
      @get_ascii_text = 'ASCII TEXT'
      controller.stub(:get_ascii_text).and_return(@get_ascii_text)
      @doc = FactoryGirl.create(:doc, :body => 'docment body')
      @former_doc_body = @doc.body
      @result = controller.rewrite_ascii([@doc])
    end
    
    it 'should replace document body' do
      @result[0].body.should_not eql(@former_doc_body)
      @doc.body.should_not eql(@former_doc_body)
    end
    
    it 'should include passed doc' do
      @result.should include(@doc)
    end
  end
  
  describe 'gen_pmdoc' do
    context 'when response code is 200' do
      before do
        pmid = '2626671'
        @result = controller.gen_pmdoc(pmid)
      end
      
      it 'should return new Doc' do
        @result.class.should eql(Doc)
      end
    end

    context 'when response code is not 200' do
      before do
        pmid = '0'
        @result = controller.gen_pmdoc(pmid)
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'gen_pmcdoc' do
    context 'when pmcdoc.doc exists' do
      context 'and when divs exists' do
        before do
          VCR.use_cassette 'controllers/application/gen_pmcdoc/div_exists' do
            @result = controller.gen_pmcdoc('2626672')
          end
        end
        
        it 'should return docs and nil' do
          @result[0].collect{|doc| doc.class}.uniq[0].should eql(Doc)
          @result[1].should be_nil
        end
      end

      context 'and when divs does not exists' do
        before do
          PMCDoc.any_instance.stub(:get_divs).and_return(nil)
          VCR.use_cassette 'controllers/application/gen_pmcdoc/div_does_not_exists' do
            @result = controller.gen_pmcdoc('2626671')
          end
        end
        
        it 'should return nil and nobody message' do
          @result.should eql([nil, "no body in the document."])
        end
      end
    end
    
    context 'when pmcdoc.doc does not exists' do
      before do
        @result = controller.gen_pmcdoc('0')
      end
      
      it 'should return nil and message' do
        @result.should eql([nil, 'PubMed Central unreachable.'])
      end
    end
  end
  
  describe 'archive_texts' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 'sourceid', :serial => 1, :section => 'section')
      controller.stub(:send_file).and_return('send file')
      @result = controller.archive_texts([@doc]) 
    end
    
    it 'return close tempfile' do
      @result.should be_nil
    end
  end
  
  describe 'archive_annotation' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc_1 = FactoryGirl.create(:doc)
      @project.docs << @doc_1 
      @doc_2 = FactoryGirl.create(:doc)
      @project.docs << @doc_2 
      @result = controller.archive_annotation(@project.name)
    end
    
    it 'should returns all of project docs in array' do
      (@result - [@doc_1, @doc_2]).should be_blank
    end
  end
  
  describe 'get_conversion' do
    context 'when response.code is 200' do
      before do
        @project = FactoryGirl.create(:project,
         :name => 'Project Name',
         :description => 'This is project description',
         :user => FactoryGirl.create(:user))
        VCR.use_cassette 'controllers/application/get_convertion/response_200' do
          @result = controller.get_conversion(@project, 'http://bionlp.dbcls.jp/ge2rdf')
        end
      end
      
      it 'should return response' do
        @result.should be_present
      end
    end
    
    context 'when response.code is not 200' do
     before do
        VCR.use_cassette 'controllers/application/get_convertion/response_not_200' do
          @result = controller.get_conversion(@project, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'gen_annotations' do
    context 'when response.code is 200' do
      before do
        @annotation = {:text => 'text', :others => 'others'}
        VCR.use_cassette 'controllers/application/gen_annotation/response_200' do
          @result = controller.gen_annotations(@annotation, 'http://nlp.dbcls.jp/biosentencer/')
        end
      end
      
      it 'should return response' do
        @result.should be_present
      end
    end
    
    context 'when response.code is not 200' do
     before do
        VCR.use_cassette 'controllers/application/gen_annotations/response_not_200' do
          @result = controller.gen_annotations(@project, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'get_annotations' do
    context 'when project annd doc exists' do
      context 'when options nothing' do
        context 'when hspans, hinstances, hrelations, hmodifications does not exists' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
            @result = controller.get_annotations(@project, @doc)
          end
          
          it 'should returns doc params' do
            @result.should eql({
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body
              })
          end
        end
      
        context 'when hspans, hinstances, hrelations, hmodifications exists' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
            @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
            @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
            @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @span, :project => @project)
            @insmod = FactoryGirl.create(:modification, :modobj => @instance, :project => @project)
            @result = controller.get_annotations(@project, @doc)
          end
          
          it 'should returns doc params, spans, instances, relations and modifications' do
            @result.should eql({
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body,
              :spans => [{:id => @span.hid, :span => {:begin => @span.begin, :end => @span.end}, :category => @span.category}],
              :instances => [{:id => @instance.hid, :type => @instance.instype, :object => @instance.insobj.hid}],
              :relations => [{:id => @subcatrel.hid, :type => @subcatrel.reltype, :subject => @subcatrel.relsub.hid, :object => @subcatrel.relobj.hid}],
              :modifications => [{:id => @insmod.hid, :type => @insmod.modtype, :object => @insmod.modobj.hid}]
              })
          end
        end
      end

      context 'when option encoding ascii exist' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @get_ascii_text = 'DOC body'
          controller.stub(:get_ascii_text).and_return(@get_ascii_text)
          @result = controller.get_annotations(@project, @doc, :encoding => 'ascii')
        end
        
        it 'should return doc params and ascii encoded text' do
          @result.should eql({
            :source_db => @doc.sourcedb, 
            :source_id => @doc.sourceid, 
            :division_id => @doc.serial, 
            :section => @doc.section, 
            :text => @get_ascii_text})
        end
      end

      context 'when option :discontinuous_annotation exist' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @get_ascii_text = 'DOC body'
          @hspans = 'hspans'
          @hrelations = 'hrelations'
          controller.stub(:bag_spans).and_return([@hspans, @hrelations])
          @result = controller.get_annotations(@project, @doc, :discontinuous_annotation => 'bag')
        end
        
        it 'should return doc params' do
          @result.should eql({
            :source_db => @doc.sourcedb, 
            :source_id => @doc.sourceid, 
            :division_id => @doc.serial, 
            :section => @doc.section, 
            :text => @doc.body,
            :spans => @hspans,
            :relations => @hrelations
            })
        end
      end
    end

    context 'anntet and doc does not exists' do
      before do
        @result = controller.get_annotations(nil, nil)
      end
      
      it 'should returns nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'save annotations' do
    context 'when spans exists' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @annotations = {:spans => 'spans', :instances => ['instance'], :relations => ['relation'], :modifications => ['modification']}
        controller.stub(:clean_hspans).and_return('clean_hspans')
        controller.stub(:realign_spans).and_return('realign_spans')
        controller.stub(:save_hspans).and_return('save_hspans')
        controller.stub(:save_hinstances).and_return('save_hinstances')
        controller.stub(:save_hrelations).and_return('save_hrelations')
        controller.stub(:save_hmodifications).and_return('save_hmodifications')
        @result = controller.save_annotations(@annotations, @project, @doc)
      end
      
      it 'should return notice message' do
        @result.should eql('Annotations were successfully created/updated.')
      end
    end
    
    context 'spans does not exists' do
      before do
        @annotations = {:spans => 'spans', :instances => ['instance'], :relations => ['relation'], :modifications => ['modification']}
        controller.stub(:clean_hspans).and_return(nil)
        @result = controller.save_annotations(@annotations, nil, nil)
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'get_spans' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
    end
    
    context 'when doc find_by_sourcedb_and_sourceid_and_serial exist' do
      before do
        @doc.projects << @project
      end
      
      context 'when doc.project.find_by_name(project_name) exists' do
        before do
          @project_another = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
          @span_another = FactoryGirl.create(:span, :project => @project_another, :doc => @doc)
          @spans = controller.get_spans(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)       
        end
        
        it 'should returns doc.spans where project_id = project.id' do
          (@spans - [@span]).should be_blank
        end
      end
      
      
      context 'when doc.project.find_by_name(project_name) does not exists' do
        before do
          @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
          @spans = controller.get_spans('none project name', @doc.sourcedb, @doc.sourceid, @doc.serial)       
        end
        
        it 'should return doc.spans' do
          (@spans - @doc.spans).should be_blank
        end
      end
    end

    context 'when doc find_by_sourcedb_and_sourceid_and_serial does not exist' do
      before do
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      end
      
      context 'when project find_by_name exist' do
        before do
          @spans = controller.get_spans(@project.name, 'nil', 'nil', 'nil')       
        end
        
        it 'should return project.spans' do
          (@spans - @project.spans).should be_blank
        end
      end
      
      context 'when project find_by_name does not exist' do
        before do
          @spans = controller.get_spans('', 'nil', 'nil', 'nil')       
        end
        
        it 'should return all spans' do
          (Span.all - @spans).should be_blank
        end
      end
    end
  end
  
  describe 'get_hspans' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      controller.stub(:get_cattanns).and_return([@span])
      @get_hash = 'get hash'
      Span.any_instance.stub(:get_hash).and_return(@get_hash)
      @hspans = controller.get_hspans('', '', '')
    end
    
    it 'should return array span.get_hash' do
      @hspans.should eql([@get_hash])
    end
  end
  
  describe 'clean_hspans' do
    context 'when format error' do
      context 'when span and begin does not present' do
        before do
          @span = {:id => 'id', :end => '5', :category => 'Category'}
          @spans = Array.new
          @spans << @span
          @result = controller.clean_hspans(@spans)
        end
        
        it 'should return nil and format error' do
          @result.should eql([nil, 'format error'])
        end
      end
  
      context 'when category does not present' do
        before do
          @span = {:id => 'id', :begin => '`1', :end => '5', :category => nil}
          @spans = Array.new
          @spans << @span
          @result = controller.clean_hspans(@spans)
        end
        
        it 'should return nil and format error' do
          @result.should eql([nil, 'format error'])
        end
      end
    end
    
    context 'when correct format' do
      before do
        @begin = '1'
        @end = '5'
        @spans = Array.new
      end

      context 'when id is nil' do
        before do
          @span = {:id => nil, :span => {:begin => @begin, :end => @end}, :category => 'Category'}
          @spans << @span
          @result = controller.clean_hspans(@spans)
        end
        
        it 'should return T + num id' do
          @result[0][0][:id].should eql('T1')
        end
      end

      context 'when span exists' do
        before do
          @span = {:id => 'id', :span => {:begin => @begin, :end => @end}, :category => 'Category'}
          @spans << @span
          @result = controller.clean_hspans(@spans)
        end
        
        it 'should return ' do
          @result.should eql([[{:id => @span[:id], :category => @span[:category], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end

      context 'when span does not exists' do
        before do
          @span = {:id => 'id', :begin => @begin, :end => @end, :category => 'Category'}
          @spans << @span
          @result = controller.clean_hspans(@spans)
        end
        
        it 'should return with span' do
          @result.should eql([[{:id => @span[:id], :category => @span[:category], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end
    end
  end
  
  describe 'save_hspans' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @hspan = {:id => 'hid', :span => {:begin => 1, :end => 10}, :category => 'Category'}
      @hspans = Array.new
      @hspans << @hspan
      @result = controller.save_hspans(@hspans, @project, @doc) 
      @span = Span.find_by_hid(@hspan[:id])
    end
    
    it 'should save successfully' do
      @result.should be_true
    end
    
    it 'should save hspan[:id] as hid' do
      @span.hid.should eql(@hspan[:id])
    end
    
    it 'should save hspan[:span][:begin] as begin' do
      @span.begin.should eql(@hspan[:span][:begin])
    end
    
    it 'should save hspan[:span][:end] as end' do
      @span.end.should eql(@hspan[:span][:end])
    end
    
    it 'should save hspan[:category] as category' do
      @span.category.should eql(@hspan[:category])
    end

    it 'should save project.id as project_id' do
      @span.project_id.should eql(@project.id)
    end

    it 'should save doc.id as doc_id' do
      @span.doc_id.should eql(@doc.id)
    end
  end
  
  describe 'chain_spans' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span_1 = FactoryGirl.create(:span, :hid => 'A1', :project => @project, :doc => @doc)
      @span_2 = FactoryGirl.create(:span, :hid => 'A2', :project => @project, :doc => @doc)
      @span_3 = FactoryGirl.create(:span, :hid => 'A3', :project => @project, :doc => @doc)
      @spans_s = [@span_1, @span_2, @span_3]
      @result = controller.chain_spans(@spans_s)
    end
    
    it 'shoulr return spans_s' do
      @result.should eql(@spans_s)
    end
  end
  
  describe 'bag_spans' do
    context 'when relation type = lexChain' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @spans = Array.new
        @spans << @span.get_hash
        @relation = FactoryGirl.create(:relation, :reltype => 'lexChain', :relobj => @span, :project => @project)
        @relations = Array.new
        @relations << @relation.get_hash
        @result = controller.bag_spans(@spans, @relations)
      end
      
      it 'spans should be_blank' do
        @result[0].should be_blank
      end

      it 'spans should be_blank' do
        @result[1].should be_blank
      end
    end
    
    context 'when relation type not = lexChain' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @spans = Array.new
        @spans << @span.get_hash
        @relation = FactoryGirl.create(:relation, :reltype => 'NotlexChain', :relobj => @span, :project => @project)
        @relations = Array.new
        @relations << @relation.get_hash
        @result = controller.bag_spans(@spans, @relations)
      end
      
      it 'spans should be_blank' do
        @result[0][0].should eql({:id => "T1", :span => {:begin => 1 , :end => 5}, :category => "Protein"})
      end
      
      it '' do
        @result[1][0].should eql(@relation.get_hash)
      end
    end
  end
  
  describe 'get_instances' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)

      @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
    end
    
    context 'when Doc find_by_sourcedb_and_sourceid_and_serial exists' do
      
      context 'when doc.projects.find_by_name exists' do
        before do
          @doc.projects << @project
          @instances = controller.get_instances(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should not return empty array' do
          @instances.should be_present
        end
        
        it 'should return doc.instances where project_id = project.id' do
          (@instances - @doc.instances.where("instances.project_id = ?", @project.id)).should be_blank
        end
      end
      
      context 'when doc.projects.find_by_name does not exists' do
        before do
          @instances = controller.get_instances(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should not return empty array' do
          @instances.should be_present
        end
        
        it 'should return @doc.instances' do
          (@instances - @doc.instances).should be_blank
        end
      end
    end

    context 'when Doc find_by_sourcedb_and_sourceid_and_serial does not exists' do
      context 'when Projectfind by project_name exists' do
        before do
          @instances = controller.get_instances(@project.name, '', '', '')
        end
        
        it 'should not return empty array' do
          @instances.should be_present
        end
        
        it 'should return project.instances' do
          (@instances - @project.instances).should be_blank
        end
      end

      context 'when Projectfind by project_name  does not exists' do
        before do
          5.times do |i|
            @instance = FactoryGirl.create(:instance, :project_id => i, :insobj_id => i)
          end
          @instances = controller.get_instances('', '', '', '')
        end
        
        it 'should not return empty array' do
          @instances.should be_present
        end
        
        it 'should return all Instance' do
          (Instance.all - @instances).should be_blank
        end
      end
    end
  end
  
  describe 'get_hinstances' do
    before do
      @instance = FactoryGirl.create(:instance, :project_id => 1, :insobj_id => 1)
      controller.stub(:get_instances).and_return([@instance])
      @get_hash = 'get hash'
      Instance.any_instance.stub(:get_hash).and_return(@get_hash)
      @hinstances = controller.get_hinstances('', '', '')
    end
    
    it 'should return instance.get_hash' do
      @hinstances.should eql([@get_hash])
    end 
  end
  
  describe 'save_hinstances' do
    before do
      @hinstance = {:id => 'hid', :type => 'type', :object => 'object'}
      @hinstances = Array.new
      @hinstances << @hinstance
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @span = FactoryGirl.create(:span, :id => 90, :project => @project, :doc => @doc, :hid => @hinstance[:object])
      @result = controller.save_hinstances(@hinstances, @project, @doc) 
    end
    
    it 'should returns saved successfully' do
      @result.should be_true
    end
    
    it 'should save Instance from args' do
      Instance.find_by_hid_and_instype_and_insobj_id_and_project_id(@hinstance[:id], @hinstance[:type], @span.id, @project.id).should be_present
    end
  end
  
  describe 'get_relations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @span, :project => @project)
      @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
      @subinsrel = FactoryGirl.create(:subcatrel, :relobj => @span, :project => @project)
    end

    context 'when doc find by sourcedb and source id and serial exists' do
      context 'when doc.projects.find by project name exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels wose project_id = project.id ' do
          (@relations - [@subcatrel, @subinsrel]).should be_blank
        end
      end

      context 'when doc.projects.find by project name exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations('', @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels' do
          (@relations - [@subcatrel, @subinsrel]).should be_blank
        end
      end
    end
    
    context 'when doc find by sourcedb and source id and serial does not exists' do
      context 'when Project.find_by_name(project_name) exists' do
        before do
          @doc.projects << @project
          @relations = controller.get_relations(@project.name, 'non existant source db', @doc.sourceid, @doc.serial)
        end
        
        it 'should return project.relations' do
          (@relations - @project.relations).should be_blank
        end
      end

      context 'when Project.find_by_name(project_name) does not exists' do
        before do
          @doc.projects << @project
          5.times do
            FactoryGirl.create(:relation, :relobj => @span, :project => @project)
          end
          @relations = controller.get_relations('non existant project name', 'non existant source db', @doc.sourceid, @doc.serial)
        end
        
        it 'should return Rellann.all' do
          (Relation.all - @relations).should be_blank
        end
      end
    end
  end
  
  describe 'get_hrelations' do
    before do
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj_id => 1, :project_id => 1)
      controller.stub(:get_relations).and_return([@subcatrel])
      Relation.any_instance.stub(:get_hash).and_return(@subcatrel.id)
      @hrelations = controller.get_hrelations('', '', '', '')
    end
    
    it 'should return array relations.get_hash got by get_relations' do
      @hrelations.should eql([@subcatrel.get_hash])
    end
  end
  
  describe 'save_hrelations' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @hrelations = Array.new
    end
    
    context 'hrelations subject and object match /^T/' do
      before do
        @hrelation = {:id => 'hid', :type => 'reltype', :subject => 'T1', :object => 'T1'}
        @hrelations << @hrelation
        @result = controller.save_hrelations(@hrelations, @project, @doc)
      end
      
      it 'should save new Relation successfully' do
        @result.should be_true
      end
      
      it 'should save from hrelations params and project, and relsub and relobj should be span' do
        Relation.where(
          :hid => @hrelation[:id], 
          :reltype => @hrelation[:type], 
          :relsub_id => @span.id, 
          :relsub_type => @span.class, 
          :relobj_id => @span.id, 
          :relobj_type => @span.class, 
          :project_id => @project.id
        ).should be_present
      end
    end

    context 'hrelations subject and object does not match /^T/' do
      before do
        @hrelation = {:id => 'hid', :type => 'reltype', :subject => 'M1', :object => 'M1'}
        @hrelations << @hrelation
        @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span, :hid => @hrelation[:subject])
        @result = controller.save_hrelations(@hrelations, @project, @doc)
      end
      
      it 'should save new Relation successfully' do
        @result.should be_true
      end
      
      it 'should save from hrelations params and project, and relsub and relobj should be instance' do
        Relation.where(
          :hid => @hrelation[:id], 
          :reltype => @hrelation[:type], 
          :relsub_id => @instance.id, 
          :relsub_type => @instance.class, 
          :relobj_id => @instance.id, 
          :relobj_type => @instance.class, 
          :project_id => @project.id
        ).should be_present
      end
    end
  end
  
  describe 'get_modifications' do
    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
        @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @span, :project => @project)
      end
      
      context 'and when doc.projects.find_by_name(project_name) exists' do
        before do
          @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @instance, :project => @project)
          @modification = FactoryGirl.create(:modification, :modobj => @instance, :project => @project)
          @subcatrelmod = FactoryGirl.create(:modification, :modobj => @subcatrel, :project => @project)
          @subinsrelmod = FactoryGirl.create(:modification, :modobj => @subinsrel, :project => @project)
          @doc.projects << @project
          @modifications = controller.get_modifications(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.insmods, doc.subcatrelmods, subinsrelmods where project_id = project.id' do
          (@modifications - [@modification, @subcatrelmod, @subinsrelmod]).should be_blank
        end
      end
      
      context 'and when doc.projects.find_by_name(project_name) does not exists' do
        before do
          @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @instance, :project => @project)
          @modification = FactoryGirl.create(:modification, :modobj => @instance, :project_id => 70)
          @subcatrelmod = FactoryGirl.create(:modification, :modobj => @subcatrel, :project_id => 80)
          @subinsrelmod = FactoryGirl.create(:modification, :modobj => @subinsrel, :project_id => 90)
          @doc.projects << @project
          @modifications = controller.get_modifications('', @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.insmodsd, doc.subcatrelmods and doc.subinsrelmods' do
          (@modifications - [@modification, @subcatrelmod, @subinsrelmod]).should be_blank
        end
      end
    end

    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) does not exists' do
      before do
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
      end
      
      context 'Project.find_by_name(project_name) exists' do
        before do
          @modification = FactoryGirl.create(:modification, :modobj => @instance, :project => @project)
          @modifications = controller.get_modifications(@project.name, '', '', '')
        end
        
        it 'should return project.modifications' do
          (@modifications - [@modification]).should be_blank
        end
      end
      
      context 'Project.find_by_name(project_name) does not exists' do
        before do
          5.times do |i|
            @modification = FactoryGirl.create(:modification, :modobj => @instance, :project_id => i)
          end
          @modifications = controller.get_modifications('', '', '', '')
        end
        
        it 'should return Modification.all' do
          (Modification.all - @modifications).should be_blank
        end
      end
    end
  end
  
  describe 'get_hmodifications' do
    before do
      @modification = FactoryGirl.create(:modification, :modobj_id => 1, :modobj_type => '', :project_id => 1)
      controller.stub(:get_modifications).and_return([@modification])
      Modification.any_instance.stub(:get_hash).and_return(@modification.id)
      @hmodifications = controller.get_hmodifications('', '', '')
    end
    
    it 'should return array modifications.get_hash' do
      @hmodifications.should eql([@modification.id])
    end
  end
  
  describe 'save_hmodifications' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
    end
    
    context 'when hmodifications[:object] match /^R/' do
      before do
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
        @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @instance, :project => @project)
        @hmodification = {:id => 'hid', :type => 'type', :object => 'R1'}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = controller.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.subinsrels' do
        Modification.where(
          :hid => @hmodification[:id],
          :modtype => @hmodification[:type],
          :modobj_id => @subinsrel.id,
          :modobj_type => @subinsrel.class
        ).should be_present
      end
    end
    
    context 'when hmodifications[:object] does not match /^R/' do
      before do
        @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
        @instance = FactoryGirl.create(:instance, :project => @project, :insobj => @span)
        @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @instance, :project => @project)
        @hmodification = {:id => 'hid', :type => 'type', :object => @instance.hid}
        @hmodifications = Array.new
        @hmodifications << @hmodification
        @result = controller.save_hmodifications(@hmodifications, @project, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modification from hmodifications params and doc.instances' do
        Modification.where(
          :hid => @hmodification[:id],
          :modtype => @hmodification[:type],
          :modobj_id => @instance.id,
          :modobj_type => @instance.class
        ).should be_present
      end
    end
  end
  
  describe 'get_ascii_test' do
    before do
      @text = 'α'
      @ascii_text = controller.get_ascii_text(@text)
    end
    
    it 'should return greek retters' do
      @ascii_text.should eql('alpha')
    end
  end
  
  describe 'realign_spans' do
    context 'when spans is nil' do
      before do
        @result = controller.realign_spans(nil, '', '')
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
    
    context 'when canann exists' do
      before do
        @begin = 1
        @end = 5
        @span = {:span => {:begin => @begin, :end => @end}}
        @spans = Array.new
        @spans << @span
        @result = controller.realign_spans(@spans, 'from text', 'end of text')
      end
      
      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end
  
  describe 'adjust_spans' do
    context 'when spans is nil' do
      before do
        @result = controller.adjust_spans(nil, '')
      end

      it 'should return nil' do
        @result.should be_nil
      end
    end

    context 'when spans exists' do
      before do
        @begin = 1
        @end = 5
        @span = {:span => {:begin => @begin, :end => @end}}
        @spans = Array.new
        @spans << @span
        @result = controller.adjust_spans(@spans, 'this is an text')
      end

      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end
  
  describe 'get_navigator' do
    before do
      controller.stub(:request).and_return(double(:fullpath => 'first/second'))
      @navigator = controller.get_navigator()
    end
    
    it 'return split request.fullpath by slash' do
      @navigator.should eql([["first", "/first"], ["second", "/first/second"]])
    end
  end
end