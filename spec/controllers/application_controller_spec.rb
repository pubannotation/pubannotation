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
  
  describe 'get_annset' do
    before do
      @user = FactoryGirl.create(:user)
    end

    context 'when ansset exists' do
      context 'and when annset.accessibility == 1' do
        before do
          @current_user = FactoryGirl.create(:user)
          controller.stub(:user_signed_in?).and_return(false)
          @annset = FactoryGirl.create(:annset, :accessibility => 1, :user => @user, :name => 'Annset Name')  
          @result = controller.get_annset(@annset.name)
        end
        
        it 'should returs annset and nil' do
          @result.should eql([@annset, nil])
        end
      end

      context 'and when annset.accessibility !=1 and annset.user == current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @annset = FactoryGirl.create(:annset, :accessibility => 2, :user => @current_user, :name => 'Annset Name')  
          @result = controller.get_annset(@annset.name)
        end
        
        it 'should returs annset and nil' do
          @result.should eql([@annset, nil])
        end
      end

      context 'and when annset.accessibility !=1 and annset.user != current_user' do
        before do
          @current_user = FactoryGirl.create(:user)
          current_user_stub(@current_user)
          @annset = FactoryGirl.create(:annset, :accessibility => 2, :user => @user, :name => 'Annset Name')  
          @result = controller.get_annset(@annset.name)
        end
        
        it 'should returs nil and message which notice annotationset is private' do
          @result.should eql([nil, "The annotation set, #{@annset.name}, is specified as private."])
        end
      end
    end
    
    context 'when ansset does not exists' do
      before do
        @result = controller.get_annset('')
      end
      
      it 'returns nil and message notice annotasion set does not exist' do
        @result.should eql([nil, "The annotation set, , does not exist."])
      end
    end
  end
  
  describe 'get_annsets' do
    before do
      @another_user = FactoryGirl.create(:user)
      @current_user = FactoryGirl.create(:user)
      @annset_accessibility_1_and_another_user_annset = FactoryGirl.create(:annset, :user => @another_user, :accessibility => 1) 
      @annset_accessibility_not_1_and_another_user_annset = FactoryGirl.create(:annset, :user => @another_user, :accessibility => 2) 
      @annset_accessibility_1_and_current_user_annset = FactoryGirl.create(:annset, :user => @current_user, :accessibility => 1) 
      @annset_accessibility_not_1_and_current_user_annset = FactoryGirl.create(:annset, :user => @current_user, :accessibility => 2) 
      current_user_stub(@current_user)
      @result = controller.get_annsets()
    end
    
    it 'should include accessibility = 1 and another users annset' do
      @result.should include(@annset_accessibility_1_and_another_user_annset)
    end
    
    it 'should not include accessibility != 1 and another users annset' do
      @result.should_not include(@annset_accessibility_not_1_and_another_user_annset)
    end
    
    it 'should include accessibility = 1 and current users annset' do
      @result.should include(@annset_accessibility_1_and_current_user_annset)
    end
    
    it 'should include accessibility != 1 and current users annset' do
      @result.should include(@annset_accessibility_not_1_and_current_user_annset)
    end
  end
  
  describe 'get_doc' do
    context 'when doc exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1)
      end

      context 'and when annset passed and doc.annsets does not include annset' do
        before do
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          @result = controller.get_doc(@doc.sourcedb, @doc.sourceid, @doc.serial, @annset)
        end
        
        it 'should return nil and message that doc does not belongs to the annotasion set' do
          @result.should eql([nil, "The document, #{@doc.sourcedb}:#{@doc.sourceid}, does not belong to the annotation set, #{@annset.name}."])
        end
      end
      
      context 'and when annset does not passed' do
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
      context 'and when annset passed and divs.first.annsets exclude annset' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'PMC', :sourceid => 1)
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          @result = controller.get_divs(@doc.sourceid, @annset)
        end
        
        it 'should return nil and message doc does not belongs to the annotation' do
          @result.should eql([nil, "The document, PMC::#{@doc.sourceid}, does not belong to the annotation set, #{@annset.name}."])
        end
      end

      context 'and when annset does not passed' do
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
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
      @doc_1 = FactoryGirl.create(:doc)
      @annset.docs << @doc_1 
      @doc_2 = FactoryGirl.create(:doc)
      @annset.docs << @doc_2 
      @result = controller.archive_annotation(@annset.name)
    end
    
    it 'should returns all of annset docs in array' do
      (@result - [@doc_1, @doc_2]).should be_blank
    end
  end
  
  describe 'get_conversion' do
    context 'when response.code is 200' do
      before do
        @annset = FactoryGirl.create(:annset,
         :name => 'Annset Name',
         :description => 'This is annset description',
         :user => FactoryGirl.create(:user))
        VCR.use_cassette 'controllers/application/get_convertion/response_200' do
          @result = controller.get_conversion(@annset, 'http://bionlp.dbcls.jp/ge2rdf')
        end
      end
      
      it 'should return response' do
        @result.should be_present
      end
    end
    
    context 'when response.code is not 200' do
     before do
        VCR.use_cassette 'controllers/application/get_convertion/response_not_200' do
          @result = controller.get_conversion(@annset, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'gen_annotations' do
    context 'when response.code is 200' do
      pending 'function not yet' do
        
      end
    end
    
    context 'when response.code is not 200' do
     before do
        VCR.use_cassette 'controllers/application/gen_annotations/response_not_200' do
          @result = controller.gen_annotations(@annset, 'http://localhost:3000')
        end
      end
      
      it 'should return nil' do
       @result.should be_nil
      end  
    end
  end
  
  describe 'get_annotations' do
    context 'when annset annd doc exists' do
      context 'when options nothing' do
        context 'when hcatanns, hinsanns, hrelanns, hmodanns does not exists' do
          before do
            @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
            @result = controller.get_annotations(@annset, @doc)
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
      
        context 'when hcatanns, hinsanns, hrelanns, hmodanns exists' do
          before do
            @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
            @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
            @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
            @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @catann, :annset => @annset)
            @insmod = FactoryGirl.create(:modann, :modobj => @insann, :annset => @annset)
            @result = controller.get_annotations(@annset, @doc)
          end
          
          it 'should returns doc params, catanns, insanns, relanns and modanns' do
            @result.should eql({
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body,
              :catanns => [{:id => @catann.hid, :span => {:begin => @catann.begin, :end => @catann.end}, :category => @catann.category}],
              :insanns => [{:id => @insann.hid, :type => @insann.instype, :object => @insann.insobj.hid}],
              :relanns => [{:id => @subcatrel.hid, :type => @subcatrel.reltype, :subject => @subcatrel.relsub.hid, :object => @subcatrel.relobj.hid}],
              :modanns => [{:id => @insmod.hid, :type => @insmod.modtype, :object => @insmod.modobj.hid}]
              })
          end
        end
      end

      context 'when option encoding ascii exist' do
        before do
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @get_ascii_text = 'DOC body'
          controller.stub(:get_ascii_text).and_return(@get_ascii_text)
          @result = controller.get_annotations(@annset, @doc, :encoding => 'ascii')
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
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @get_ascii_text = 'DOC body'
          @hcatanns = 'hcatanns'
          @hrelanns = 'hrelanns'
          controller.stub(:bag_catanns).and_return([@hcatanns, @hrelanns])
          @result = controller.get_annotations(@annset, @doc, :discontinuous_annotation => 'bag')
        end
        
        it 'should return doc params' do
          @result.should eql({
            :source_db => @doc.sourcedb, 
            :source_id => @doc.sourceid, 
            :division_id => @doc.serial, 
            :section => @doc.section, 
            :text => @doc.body,
            :catanns => @hcatanns,
            :relanns => @hrelanns
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
    context 'when catanns exists' do
      before do
        @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @annotations = {:catanns => 'catanns', :insanns => ['insann'], :relanns => ['relann'], :modanns => ['modann']}
        controller.stub(:clean_hcatanns).and_return('clean_hcatanns')
        controller.stub(:realign_catanns).and_return('realign_catanns')
        controller.stub(:save_hcatanns).and_return('save_hcatanns')
        controller.stub(:save_hinsanns).and_return('save_hinsanns')
        controller.stub(:save_hrelanns).and_return('save_hrelanns')
        controller.stub(:save_hmodanns).and_return('save_hmodanns')
        @result = controller.save_annotations(@annotations, @annset, @doc)
      end
      
      it 'should return notice message' do
        @result.should eql('Annotations were successfully created/updated.')
      end
    end
    
    context 'catanns does not exists' do
      before do
        @annotations = {:catanns => 'catanns', :insanns => ['insann'], :relanns => ['relann'], :modanns => ['modann']}
        controller.stub(:clean_hcatanns).and_return(nil)
        @result = controller.save_annotations(@annotations, nil, nil)
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
  end
  
  describe 'get_catanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
    end
    
    context 'when doc find_by_sourcedb_and_sourceid_and_serial exist' do
      before do
        @doc.annsets << @annset
      end
      
      context 'when doc.annset.find_by_name(annset_name) exists' do
        before do
          @annset_another = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
          @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
          @catann_another = FactoryGirl.create(:catann, :annset => @annset_another, :doc => @doc)
          @catanns = controller.get_catanns(@annset.name, @doc.sourcedb, @doc.sourceid, @doc.serial)       
        end
        
        it 'should returns doc.catanns where annset_id = annset.id' do
          (@catanns - [@catann]).should be_blank
        end
      end
      
      
      context 'when doc.annset.find_by_name(annset_name) does not exists' do
        before do
          @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
          @catanns = controller.get_catanns('none annset name', @doc.sourcedb, @doc.sourceid, @doc.serial)       
        end
        
        it 'should return doc.catanns' do
          (@catanns - @doc.catanns).should be_blank
        end
      end
    end

    context 'when doc find_by_sourcedb_and_sourceid_and_serial does not exist' do
      before do
        @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
      end
      
      context 'when annset find_by_name exist' do
        before do
          @catanns = controller.get_catanns(@annset.name, 'nil', 'nil', 'nil')       
        end
        
        it 'should return annset.catanns' do
          (@catanns - @annset.catanns).should be_blank
        end
      end
      
      context 'when annset find_by_name does not exist' do
        before do
          @catanns = controller.get_catanns('', 'nil', 'nil', 'nil')       
        end
        
        it 'should return all catanns' do
          (Catann.all - @catanns).should be_blank
        end
      end
    end
  end
  
  describe 'get_hcatanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
      controller.stub(:get_cattanns).and_return([@catann])
      @get_hash = 'get hash'
      Catann.any_instance.stub(:get_hash).and_return(@get_hash)
      @hcatanns = controller.get_hcatanns('', '', '')
    end
    
    it 'should return array catann.get_hash' do
      @hcatanns.should eql([@get_hash])
    end
  end
  
  describe 'clean_hcatanns' do
    context 'when format error' do
      context 'when span and begin does not present' do
        before do
          @catann = {:id => 'id', :end => '5', :category => 'Category'}
          @catanns = Array.new
          @catanns << @catann
          @result = controller.clean_hcatanns(@catanns)
        end
        
        it 'should return nil and format error' do
          @result.should eql([nil, 'format error'])
        end
      end
  
      context 'when category does not present' do
        before do
          @catann = {:id => 'id', :begin => '`1', :end => '5', :category => nil}
          @catanns = Array.new
          @catanns << @catann
          @result = controller.clean_hcatanns(@catanns)
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
        @catanns = Array.new
      end

      context 'when id is nil' do
        before do
          @catann = {:id => nil, :span => {:begin => @begin, :end => @end}, :category => 'Category'}
          @catanns << @catann
          @result = controller.clean_hcatanns(@catanns)
        end
        
        it 'should return T + num id' do
          @result[0][0][:id].should eql('T1')
        end
      end

      context 'when span exists' do
        before do
          @catann = {:id => 'id', :span => {:begin => @begin, :end => @end}, :category => 'Category'}
          @catanns << @catann
          @result = controller.clean_hcatanns(@catanns)
        end
        
        it 'should return ' do
          @result.should eql([[{:id => @catann[:id], :category => @catann[:category], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end

      context 'when span does not exists' do
        before do
          @catann = {:id => 'id', :begin => @begin, :end => @end, :category => 'Category'}
          @catanns << @catann
          @result = controller.clean_hcatanns(@catanns)
        end
        
        it 'should return with span' do
          @result.should eql([[{:id => @catann[:id], :category => @catann[:category], :span => {:begin => @begin.to_i, :end => @end.to_i}}], nil])
        end
      end
    end
  end
  
  describe 'save_hcatanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @hcatann = {:id => 'hid', :span => {:begin => 1, :end => 10}, :category => 'Category'}
      @hcatanns = Array.new
      @hcatanns << @hcatann
      @result = controller.save_hcatanns(@hcatanns, @annset, @doc) 
      @catann = Catann.find_by_hid(@hcatann[:id])
    end
    
    it 'should save successfully' do
      @result.should be_true
    end
    
    it 'should save hcatann[:id] as hid' do
      @catann.hid.should eql(@hcatann[:id])
    end
    
    it 'should save hcatann[:span][:begin] as begin' do
      @catann.begin.should eql(@hcatann[:span][:begin])
    end
    
    it 'should save hcatann[:span][:end] as end' do
      @catann.end.should eql(@hcatann[:span][:end])
    end
    
    it 'should save hcatann[:category] as category' do
      @catann.category.should eql(@hcatann[:category])
    end

    it 'should save annset.id as annset_id' do
      @catann.annset_id.should eql(@annset.id)
    end

    it 'should save doc.id as doc_id' do
      @catann.doc_id.should eql(@doc.id)
    end
  end
  
  describe 'chain_catanns' do
    before do
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @catann_1 = FactoryGirl.create(:catann, :hid => 'A1', :annset => @annset, :doc => @doc)
      @catann_2 = FactoryGirl.create(:catann, :hid => 'A2', :annset => @annset, :doc => @doc)
      @catann_3 = FactoryGirl.create(:catann, :hid => 'A3', :annset => @annset, :doc => @doc)
      @catanns_s = [@catann_1, @catann_2, @catann_3]
      @result = controller.chain_catanns(@catanns_s)
    end
    
    it 'shoulr return catanns_s' do
      @result.should eql(@catanns_s)
    end
  end
  
  describe 'bag_catanns' do
  #  pending 'because object.property should be symbol' do
      context 'when relann type = lexChain' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
          @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
          @catanns = Array.new
          @catanns << @catann.get_hash
          @relann = FactoryGirl.create(:relann, :reltype => 'lexChain', :relobj => @catann, :annset => @annset)
          @relanns = Array.new
          @relanns << @relann.get_hash
          @result = controller.bag_catanns(@catanns, @relanns)
        end
        
        it 'catanns should be_blank' do
          @result[0].should be_blank
        end

        it 'catanns should be_blank' do
          @result[1].should be_blank
        end
      end
      
      context 'when relann type not = lexChain' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
          @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
          @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
          @catanns = Array.new
          @catanns << @catann.get_hash
          @relann = FactoryGirl.create(:relann, :reltype => 'NotlexChain', :relobj => @catann, :annset => @annset)
          @relanns = Array.new
          @relanns << @relann.get_hash
          @result = controller.bag_catanns(@catanns, @relanns)
        end
        
        it 'catanns should be_blank' do
          @result[0][0].should eql({:id => "T1", :span => {:begin => 1 , :end => 5}, :category => "Protein"})
        end
        
        it '' do
          @result[1][0].should eql(@relann.get_hash)
        end
      end
#    end
  end
  
  describe 'get_insanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)

      @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
    end
    
    context 'when Doc find_by_sourcedb_and_sourceid_and_serial exists' do
      
      context 'when doc.annsets.find_by_name exists' do
        before do
          @doc.annsets << @annset
          @insanns = controller.get_insanns(@annset.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should not return empty array' do
          @insanns.should be_present
        end
        
        it 'should return doc.insanns where annset_id = annset.id' do
          (@insanns - @doc.insanns.where("insanns.annset_id = ?", @annset.id)).should be_blank
        end
      end
      
      context 'when doc.annsets.find_by_name does not exists' do
        before do
          @insanns = controller.get_insanns(@annset.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should not return empty array' do
          @insanns.should be_present
        end
        
        it 'should return @doc.insanns' do
          (@insanns - @doc.insanns).should be_blank
        end
      end
    end

    context 'when Doc find_by_sourcedb_and_sourceid_and_serial does not exists' do
      context 'when Annsetfind by annset_name exists' do
        before do
          @insanns = controller.get_insanns(@annset.name, '', '', '')
        end
        
        it 'should not return empty array' do
          @insanns.should be_present
        end
        
        it 'should return annset.insanns' do
          (@insanns - @annset.insanns).should be_blank
        end
      end

      context 'when Annsetfind by annset_name  does not exists' do
        before do
          5.times do |i|
            @insann = FactoryGirl.create(:insann, :annset_id => i, :insobj_id => i)
          end
          @insanns = controller.get_insanns('', '', '', '')
        end
        
        it 'should not return empty array' do
          @insanns.should be_present
        end
        
        it 'should return all Insann' do
          (Insann.all - @insanns).should be_blank
        end
      end
    end
  end
  
  describe 'get_hinsanns' do
    before do
      @insann = FactoryGirl.create(:insann, :annset_id => 1, :insobj_id => 1)
      controller.stub(:get_insanns).and_return([@insann])
      @get_hash = 'get hash'
      Insann.any_instance.stub(:get_hash).and_return(@get_hash)
      @hinsanns = controller.get_hinsanns('', '', '')
    end
    
    it 'should return insann.get_hash' do
      @hinsanns.should eql([@get_hash])
    end 
  end
  
  describe 'save_hinsanns' do
    before do
      @hinsann = {:id => 'hid', :type => 'type', :object => 'object'}
      @hinsanns = Array.new
      @hinsanns << @hinsann
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @catann = FactoryGirl.create(:catann, :id => 90, :annset => @annset, :doc => @doc, :hid => @hinsann[:object])
      @result = controller.save_hinsanns(@hinsanns, @annset, @doc) 
    end
    
    it 'should returns saved successfully' do
      @result.should be_true
    end
    
    it 'should save Insann from args' do
      Insann.find_by_hid_and_instype_and_insobj_id_and_annset_id(@hinsann[:id], @hinsann[:type], @catann.id, @annset.id).should be_present
    end
  end
  
  describe 'get_relanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @catann, :annset => @annset)
      @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
      @subinsrel = FactoryGirl.create(:subcatrel, :relobj => @catann, :annset => @annset)
    end

    context 'when doc find by sourcedb and source id and serial exists' do
      context 'when doc.annsets.find by annset name exists' do
        before do
          @doc.annsets << @annset
          @relanns = controller.get_relanns(@annset.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels wose annset_id = annset.id ' do
          (@relanns - [@subcatrel, @subinsrel]).should be_blank
        end
      end

      context 'when doc.annsets.find by annset name exists' do
        before do
          @doc.annsets << @annset
          @relanns = controller.get_relanns('', @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.subcatrels and doc.subinsrels' do
          (@relanns - [@subcatrel, @subinsrel]).should be_blank
        end
      end
    end
    
    context 'when doc find by sourcedb and source id and serial does not exists' do
      context 'when Annset.find_by_name(annset_name) exists' do
        before do
          @doc.annsets << @annset
          @relanns = controller.get_relanns(@annset.name, 'non existant source db', @doc.sourceid, @doc.serial)
        end
        
        it 'should return annset.relanns' do
          (@relanns - @annset.relanns).should be_blank
        end
      end

      context 'when Annset.find_by_name(annset_name) does not exists' do
        before do
          @doc.annsets << @annset
          5.times do
            FactoryGirl.create(:relann, :relobj => @catann, :annset => @annset)
          end
          @relanns = controller.get_relanns('non existant annset name', 'non existant source db', @doc.sourceid, @doc.serial)
        end
        
        it 'should return Rellann.all' do
          (Relann.all - @relanns).should be_blank
        end
      end
    end
  end
  
  describe 'get_hrelanns' do
    before do
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj_id => 1, :annset_id => 1)
      controller.stub(:get_relanns).and_return([@subcatrel])
      Relann.any_instance.stub(:get_hash).and_return(@subcatrel.id)
      @hrelanns = controller.get_hrelanns('', '', '', '')
    end
    
    it 'should return array relanns.get_hash got by get_relanns' do
      @hrelanns.should eql([@subcatrel.get_hash])
    end
  end
  
  describe 'save_hrelanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
      @hrelanns = Array.new
    end
    
    context 'hrelanns subject and object match /^T/' do
      before do
        @hrelann = {:id => 'hid', :type => 'reltype', :subject => 'T1', :object => 'T1'}
        @hrelanns << @hrelann
        @result = controller.save_hrelanns(@hrelanns, @annset, @doc)
      end
      
      it 'should save new Relann successfully' do
        @result.should be_true
      end
      
      it 'should save from hrelanns params and annset, and relsub and relobj should be catann' do
        Relann.where(
          :hid => @hrelann[:id], 
          :reltype => @hrelann[:type], 
          :relsub_id => @catann.id, 
          :relsub_type => @catann.class, 
          :relobj_id => @catann.id, 
          :relobj_type => @catann.class, 
          :annset_id => @annset.id
        ).should be_present
      end
    end

    context 'hrelanns subject and object does not match /^T/' do
      before do
        @hrelann = {:id => 'hid', :type => 'reltype', :subject => 'M1', :object => 'M1'}
        @hrelanns << @hrelann
        @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann, :hid => @hrelann[:subject])
        @result = controller.save_hrelanns(@hrelanns, @annset, @doc)
      end
      
      it 'should save new Relann successfully' do
        @result.should be_true
      end
      
      it 'should save from hrelanns params and annset, and relsub and relobj should be insann' do
        Relann.where(
          :hid => @hrelann[:id], 
          :reltype => @hrelann[:type], 
          :relsub_id => @insann.id, 
          :relsub_type => @insann.class, 
          :relobj_id => @insann.id, 
          :relobj_type => @insann.class, 
          :annset_id => @annset.id
        ).should be_present
      end
    end
  end
  
  describe 'get_modanns' do
    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) exists' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
        @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
        @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
        @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
        @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @catann, :annset => @annset)
      end
      
      context 'and when doc.annsets.find_by_name(annset_name) exists' do
        before do
          @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @insann, :annset => @annset)
          @modann = FactoryGirl.create(:modann, :modobj => @insann, :annset => @annset)
          @subcatrelmod = FactoryGirl.create(:modann, :modobj => @subcatrel, :annset => @annset)
          @subinsrelmod = FactoryGirl.create(:modann, :modobj => @subinsrel, :annset => @annset)
          @doc.annsets << @annset
          @modanns = controller.get_modanns(@annset.name, @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.insmods, doc.subcatrelmods, subinsrelmods where annset_id = annset.id' do
          (@modanns - [@modann, @subcatrelmod, @subinsrelmod]).should be_blank
        end
      end
      
      context 'and when doc.annsets.find_by_name(annset_name) does not exists' do
        before do
          @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @insann, :annset => @annset)
          @modann = FactoryGirl.create(:modann, :modobj => @insann, :annset_id => 70)
          @subcatrelmod = FactoryGirl.create(:modann, :modobj => @subcatrel, :annset_id => 80)
          @subinsrelmod = FactoryGirl.create(:modann, :modobj => @subinsrel, :annset_id => 90)
          @doc.annsets << @annset
          @modanns = controller.get_modanns('', @doc.sourcedb, @doc.sourceid, @doc.serial)
        end
        
        it 'should return doc.insmodsd, doc.subcatrelmods and doc.subinsrelmods' do
          (@modanns - [@modann, @subcatrelmod, @subinsrelmod]).should be_blank
        end
      end
    end

    context 'when Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial) does not exists' do
      before do
        @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
      end
      
      context 'Annset.find_by_name(annset_name) exists' do
        before do
          @modann = FactoryGirl.create(:modann, :modobj => @insann, :annset => @annset)
          @modanns = controller.get_modanns(@annset.name, '', '', '')
        end
        
        it 'should return annset.modanns' do
          (@modanns - [@modann]).should be_blank
        end
      end
      
      context 'Annset.find_by_name(annset_name) does not exists' do
        before do
          5.times do |i|
            @modann = FactoryGirl.create(:modann, :modobj => @insann, :annset_id => i)
          end
          @modanns = controller.get_modanns('', '', '', '')
        end
        
        it 'should return Modann.all' do
          (Modann.all - @modanns).should be_blank
        end
      end
    end
  end
  
  describe 'get_hmodanns' do
    before do
      @modann = FactoryGirl.create(:modann, :modobj_id => 1, :modobj_type => '', :annset_id => 1)
      controller.stub(:get_modanns).and_return([@modann])
      Modann.any_instance.stub(:get_hash).and_return(@modann.id)
      @hmodanns = controller.get_hmodanns('', '', '')
    end
    
    it 'should return array modanns.get_hash' do
      @hmodanns.should eql([@modann.id])
    end
  end
  
  describe 'save_hmodanns' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user), :name => "annset_name")
    end
    
    context 'when hmodanns[:object] match /^R/' do
      before do
        @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
        @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
        @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @insann, :annset => @annset)
        @hmodann = {:id => 'hid', :type => 'type', :object => 'R1'}
        @hmodanns = Array.new
        @hmodanns << @hmodann
        @result = controller.save_hmodanns(@hmodanns, @annset, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modann from hmodanns params and doc.subinsrels' do
        Modann.where(
          :hid => @hmodann[:id],
          :modtype => @hmodann[:type],
          :modobj_id => @subinsrel.id,
          :modobj_type => @subinsrel.class
        ).should be_present
      end
    end
    
    context 'when hmodanns[:object] does not match /^R/' do
      before do
        @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
        @insann = FactoryGirl.create(:insann, :annset => @annset, :insobj => @catann)
        @subinsrel = FactoryGirl.create(:subinsrel, :relobj => @insann, :annset => @annset)
        @hmodann = {:id => 'hid', :type => 'type', :object => @insann.hid}
        @hmodanns = Array.new
        @hmodanns << @hmodann
        @result = controller.save_hmodanns(@hmodanns, @annset, @doc)
      end
      
      it 'should save successfully' do
        @result.should be_true
      end
      
      it 'should save Modann from hmodanns params and doc.insanns' do
        Modann.where(
          :hid => @hmodann[:id],
          :modtype => @hmodann[:type],
          :modobj_id => @insann.id,
          :modobj_type => @insann.class
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
  
  describe 'realign_catanns' do
    context 'when catanns is nil' do
      before do
        @result = controller.realign_catanns(nil, '', '')
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
    
    context 'when canann exists' do
      before do
        @begin = 1
        @end = 5
        @catann = {:span => {:begin => @begin, :end => @end}}
        @catanns = Array.new
        @catanns << @catann
        @result = controller.realign_catanns(@catanns, 'from text', 'end of text')
      end
      
      it 'should change positions' do
        (@result[0][:span][:begin] == @begin && @result[0][:span][:end] == @end).should be_false
      end
    end
  end
  
  describe 'adjust_catanns' do
    context 'when catanns is nil' do
      before do
        @result = controller.adjust_catanns(nil, '')
      end

      it 'should return nil' do
        @result.should be_nil
      end
    end

    context 'when catanns exists' do
      before do
        @begin = 1
        @end = 5
        @catann = {:span => {:begin => @begin, :end => @end}}
        @catanns = Array.new
        @catanns << @catann
        @result = controller.adjust_catanns(@catanns, 'this is an text')
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