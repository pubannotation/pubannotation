# encoding: utf-8
require 'spec_helper'

describe AnnotationsHelper do
  describe 'get_annotations' do
    context 'when doc exists' do
      context 'when hdenotations, hrelations, hmodifications exists' do
        before do
          @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
          @hdenotations = 'hdnotations'
          @doc.stub(:hdenotations).and_return(@hdenotations)
          @hrelations = 'hrelations'
          @doc.stub(:hrelations).and_return(@hrelations)
          @hmodifications = 'hmodifications'
          @doc.stub(:hmodifications).and_return(@hmodifications)
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
        end
  
        context 'when option encoding ascii exist' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1234566', :serial => 1, :section => 'section', :body => 'doc body')
            @get_ascii_text = 'DOC body'
            helper.stub(:get_ascii_text).and_return(@get_ascii_text)
            @result = helper.get_annotations(@project, @doc, :encoding => 'ascii')
          end
  
          it 'should return doc params and ascii encoded text' do
            @result.should eql({
              :project => @project.name,
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
            @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1111', :serial => 1, :section => 'section', :body => 'doc body')
            @get_ascii_text = 'DOC body'
            @hdenotations = 'hdenotations'
            @hrelations = 'hrelations'
            helper.stub(:bag_denotations).and_return([@hdenotations, @hrelations])
            @result = helper.get_annotations(@project, @doc, :discontinuous_annotation => 'bag')
          end
          
          it 'should return doc params' do
            @result.should eql({
              :project => @project.name,
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body,
              :denotations => @hdenotations,
              :relations => @hrelations
              })
          end
        end
        
        context 'when project.presentt' do
          before do
            @result = helper.get_annotations(@project, @doc)
          end
          
          it 'should returns doc params, denotations, instances, relations and modifications' do
            @result.should eql({
              :project => @project.name,
              :source_db => @doc.sourcedb, 
              :source_id => @doc.sourceid, 
              :division_id => @doc.serial, 
              :section => @doc.section, 
              :text => @doc.body,
              :denotations => @hdenotations,
              :relations => @hrelations, 
              :modifications => @hmodifications
              })
          end
        end
      end
    end

    context 'anntet and doc does not exists' do
      before do
        @result = helper.get_annotations(nil, nil)
      end
      
      it 'should returns nil' do
        @result.should be_nil
      end
    end
  end  

  describe 'annotaitons[:focus]' do
    context 'when context_size blank' do
      before do
        @params_begin = 1
        @params_end = 5
        @annotations = helper.get_focus(params: {begin: @params_begin, end: @params_end})
      end

      it 'annotaitons[:focus][:begin] should be 0' do
        expect(@annotations[:begin]).to eql(0) 
      end

      it 'annotaitons[:focus][:end] should equal gap of begin - end' do
        expect(@annotations[:end]).to eql(@params_end - @params_begin) 
      end
    end

    context 'when context_size present' do
      before do
        @params_begin = 1
        @params_end = 5
        @context_size = 6
        @annotations = helper.get_focus(params: {begin: @params_begin, end: @params_end, context_size: @context_size})
      end

      it 'annotaitons[:focus][:begin] should be params[:context_size]' do
        expect(@annotations[:begin]).to eql(@context_size) 
      end

      it 'annotaitons[:focus][:end] should equal gap of begin - end + params[:context_size]' do
        expect(@annotations[:end]).to eql(@params_end - @params_begin + @context_size) 
      end
    end
  end

  describe 'get_annotations_for_json' do
    context 'when doc present' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'SDB', :sourceid => 123, :body => 'annotation doc body')
        @hdenotations = 'hdenotations'
        @hrelations = 'hrelations'
        @hmodifications = 'hmodifications'
      end

      context 'when doc.has_divs? == true' do
        before do
          @doc.stub(:has_divs?).and_return(true)
          @annotations = helper.get_annotations_for_json(nil, @doc)
        end
        
        it 'should set divs#show path as target' do
          expect(@annotations[:target]).to eql(doc_sourcedb_sourceid_divs_show_path(@doc.sourcedb, @doc.sourceid, @doc.serial, :only_path => false))
        end
      end

      context 'when doc.has_divs? == false' do
        before do
          @doc.stub(:has_divs?).and_return(false)
          @annotations = helper.get_annotations_for_json(nil, @doc)
        end
        
        it 'should set docs#show path as target' do
          expect(@annotations[:target]).to eql(doc_sourcedb_sourceid_show_path(@doc.sourcedb, @doc.sourceid, :only_path => false))
        end
      end
      
      context  'when project blank'  do
        context  'when no options'  do
          before do
            @annotations = helper.get_annotations_for_json(nil, @doc)
          end
               
          it 'should not return :project' do
            @annotations[:project].should be_nil
          end
               
          it 'should return doc_sourcedb_sourceid_show_path as :target' do
            @annotations[:target].should eql(doc_sourcedb_sourceid_show_path(@doc.sourcedb, @doc.sourceid, :only_path => false))
          end
               
          it 'should return doc.body as :text' do
            @annotations[:text].should eql(@doc.body)
          end
               
          it 'should not return :denotations' do
            @annotations[:denotations].should be_nil
          end
               
          it 'should not return :relations' do
            @annotations[:relations].should be_nil
          end
               
          it 'should not return :modifications' do
            @annotations[:modifications].should be_nil
          end
        end
        
        context 'when docs.projects present' do
          before do
            @doc.stub_chain(:projects, :name_in).and_return([0, 1])
            helper.stub(:get_annotation_relational_models).and_return(nil)
            @annotations = helper.get_annotations_for_json(nil, @doc, projects: 'projects')
          end
          
          it 'should set tracks' do
            @annotations[:tracks].should =~ [{}, {}]
          end
        end
      
        context  'when options[:encoding] == ascii'  do
          before do
            @ascii_text = 'ascii text'
            helper.stub(:get_ascii_text).and_return(@ascii_text)
            @annotations = helper.get_annotations_for_json(nil, @doc, :encoding => 'ascii')
          end
               
          it 'should return asciitext as :text' do
            @annotations[:text].should eql(@ascii_text)
          end
        end        
      end
      
      context  'when project present' do
        before do
          @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
          @doc.stub(:hdenotations).and_return(@hdenotations)
          @doc.stub(:hrelations).and_return(@hrelations)
          @doc.stub(:hmodifications).and_return(@hmodifications)
        end
        
        context 'no options' do
          before do
            @annotations = helper.get_annotations_for_json(@project, @doc)
          end
               
          it 'should return project_path as :project' do
            @annotations[:project].should eql(project_path(@project.name, :only_path => false))
          end
               
          it 'should return equence_alignment.transform_denotations as :hdenotations' do
            @annotations[:denotations].should eql(@hdenotations)
          end
               
          it 'should not return :relations' do
            @annotations[:relations].should eql(@hrelations)
          end
               
          it 'should not return :modifications' do
            @annotations[:modifications].should eql(@hmodifications)
          end
        end

        context  'when options[:discontinuous_annotation] == bag'  do
          before do
            helper.stub(:bag_denotations).and_return([@hdenotations, @hrelations])
            @annotations = helper.get_annotations_for_json(@project, @doc, :discontinuous_annotation => 'bag')
          end
               
          it 'should return equence_alignment.transform_denotations as :hdenotations' do
            @annotations[:denotations].should eql(@hdenotations)
          end
               
          it 'should not return :relations' do
            @annotations[:relations].should eql(@hrelations)
          end
        end
        
        context  'when options[:encoding] == ascii'  do
          before do
            @ascii_text = 'ascii text'
            helper.stub(:get_ascii_text).and_return(@ascii_text)
            SequenceAlignment.any_instance.stub(:initialize).and_return(nil)
            SequenceAlignment.any_instance.stub(:transform_denotations).and_return(@hdenotations)
            @annotations = helper.get_annotations_for_json(@project, @doc, :encoding => 'ascii')
          end
               
          it 'should return asciitext as :text' do
            @annotations[:text].should eql(@ascii_text)
          end
               
          it 'should return equence_alignment.transform_denotations as :hdenotations' do
            @annotations[:denotations].should eql(@hdenotations)
          end
        end
      end

      context 'when doc_spans present' do
        before do
          @doc_text = 'doc text'
          @doc.stub(:text).and_return(@doc_text)
          @doc_projects = [@project]
          @doc.stub_chain(:projects, :name_in).and_return(@doc_projects)
          @denotations_span_begin = 5
          @denotations_span_end = 10
          @denotations = [{span: {begin: @denotations_span_begin, end: @denotations_span_end}}]
          @params_begin = 1
          @params_end = 2
          @annotation_relational_models = {denotations: @denotations}
          helper.stub(:get_annotation_relational_models) do |doc, project, text, asciitext, annotaitons, options|
            annotaitons[:denotations] = @denotations
          end
          @set_denotations_begin_end = 'set begin end'
          helper.stub(:set_denotations_begin_end).and_return(@set_denotations_begin_end)
        end

        describe 'text' do
          before do
            @annotations = helper.get_annotations_for_json(nil, @doc, doc_spans: 'spans', params: {begin: @params_begin, end: @params_end})
          end

          it 'should set set_denotations_begin_end values as track[:denotations]' do
            expect(@annotations[:text]).to eql(@doc_text)
          end
        end

        context 'when tracks present' do
          before do
            @annotations = helper.get_annotations_for_json(nil, @doc, doc_spans: 'spans', params: {begin: @params_begin, end: @params_end})
          end

          it 'should set set_denotations_begin_end values as track[:denotations]' do
            expect(@annotations[:tracks][0][:denotations]).to eql(@set_denotations_begin_end)
          end
        end

        context 'when denotations present' do
          before do
            @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
            @annotations = helper.get_annotations_for_json(@project, @doc, doc_spans: 'spans', params: {begin: @params_begin, end: @params_end})
          end

          it 'should set set_denotations_begin_end values as annotaitons[:denotations]' do
            expect(@annotations[:denotations]).to eql(@set_denotations_begin_end)
          end
        end

        describe 'annotaitons[:focus]' do
          before do
            @get_focus = 'get_focus'
            helper.stub(:get_focus).and_return(@get_focus)
            @annotations = helper.get_annotations_for_json(nil, @doc, {})
          end

          it 'annotaitons[:focus][:begin] should be 0' do
            expect(@annotations[:focus]).to eql(@get_focus) 
          end
        end
      end
    end

    context 'when doc blank' do
      before do
        @annotations = helper.get_annotations_for_json(nil, nil)
      end
      
      it 'should return nil' do
        @annotations.should be_nil
      end
    end
  end

  describe 'set_denotations_begin_end' do
    before do
      @begin = 50
      @end = 60
      @denotations = [{span: {begin: @begin, end: @end}}]
      @params_begin = 50
      @params_end = 60
      @context_size = 5
    end

    context 'when options context_size blank' do
      before do
        @options = {params: {begin: @params_begin, end: @params_end} }
        @denotations = helper.set_denotations_begin_end(@denotations, @options)
      end

      it 'span begin should denotations[:begin] - params[:begin]' do
        expect(@denotations[0][:span][:begin]).to eql(@begin - @params_begin)
      end

      it 'span end should denotations[:end] - params[:begin]' do
        expect(@denotations[0][:span][:end]).to eql(@end - @begin)
      end
    end

    context 'when options context_size present' do
      before do
        @options = {params: {begin: @params_begin, end: @params_end, context_size: @context_size} }
        @denotations = helper.set_denotations_begin_end(@denotations, @options)
      end

      it 'span begin should denotations[:begin] - params[:begin] + context_size' do
        expect(@denotations[0][:span][:begin]).to eql(@begin - @params_begin + @context_size)
      end

      it 'span end should denotations[:end] - params[:begin] + context_size' do
        expect(@denotations[0][:span][:end]).to eql(@end - @begin + @context_size)
      end
    end
  end
  
  describe 'get_annotation_relational_models' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'SDB', :sourceid => 123, :body => 'annotation doc body')
      @hrelations = 'hrelations'
      @hmodifications = 'hmodifications'
      @hdenotations = 'hdenotations'
      @doc.stub(:hrelations).and_return(@hrelations)
      @doc.stub(:hmodifications).and_return(@hmodifications)
      @doc.stub(:hdenotations).and_return(@hdenotations)
      @transform_denotations = 'transform_denotations'
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @text = 'doc body'
      @asciitext = 'ascii text'
      @annotations_hash = {}
    end
    
    context 'when no options' do
      before do
        @annotations = helper.get_annotation_relational_models(@doc, @project, @text, nil, @annotations_hash, {})
      end
      
      it 'should return project_path as :project' do
        @annotations[:project].should eql(project_path(@project.name, :only_path => false))
      end
  
      it 'should return equence_alignment.transform_denotations as :hdenotations' do
        @annotations[:denotations].should eql(@hdenotations)
      end
           
      it 'should not return :relations' do
        @annotations[:relations].should eql(@hrelations)
      end
           
      it 'should not return :modifications' do
        @annotations[:modifications].should eql(@hmodifications)
      end
    end
    
    context  'when options[:encoding] == ascii'  do
      before do
        helper.stub(:get_ascii_text).and_return(@asciitext)
        SequenceAlignment.any_instance.stub(:initialize).and_return(nil)
        SequenceAlignment.any_instance.stub(:transform_denotations).and_return(@transform_denotations)
        @annotations = helper.get_annotation_relational_models(@doc, @project, @text, @asciitext, @annotations_hash, :encoding => 'ascii')
      end
           
      it 'should return equence_alignment.transform_denotations as :hdenotations' do
        @annotations[:denotations].should eql(@transform_denotations)
      end
    end
    
    context  'when options[:discontinuous_annotation] == bag'  do
      before do
        @hdenotations_bag = 'hdenotations_bag'
        @hrelations_bag = 'hrelations_bag'
        helper.stub(:bag_denotations).and_return([@hdenotations_bag, @hrelations_bag])
        @annotations = helper.get_annotations_for_json(@project, @doc, :discontinuous_annotation => 'bag')
      end
           
      it 'should return equence_alignment.transform_denotations as :hdenotations' do
        @annotations[:denotations].should eql(@hdenotations_bag)
      end
           
      it 'should not return :relations' do
        @annotations[:relations].should eql(@hrelations_bag)
      end
    end
  end
  
  describe 'bag_denotations' do
    context 'when relation type = lexChain' do
      before do
        doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        denotation1 = FactoryGirl.create(:denotation, :project => project, :doc => doc)
        denotation2 = FactoryGirl.create(:denotation, :project => project, :doc => doc)
        denotations = Array.new
        denotations << denotation1.get_hash << denotation2.get_hash
        relation = FactoryGirl.create(:relation, 
          :pred => '_lexChain',
          :obj_id => denotation1.id,
          :project => project,
          :subj_id => denotation2.id,
          :subj_type => 'Denotation')
        relations = Array.new
        relations << relation.get_hash
        @new_denotations, @new_relations = helper.bag_denotations(denotations, relations)
      end
      
      it 'denotations should be_blank' do
        @new_denotations[1].should be_blank
      end

      it 'denotations should be_blank' do
        @new_relations[0].should be_blank
      end
    end
    
    context 'when relation type not = lexChain' do
      before do
        @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '1', :serial => 1, :section => 'section', :body => 'doc body')
        @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => "project_name")
        @denotation = FactoryGirl.create(:denotation, :project => @project, :doc => @doc)
        @denotations = Array.new
        @denotations << @denotation.get_hash
        @relation = FactoryGirl.create(:relation, 
          :pred => 'NotlexChain',
          :obj => @denotation, 
          :project => @project,
          :subj_id => @denotation.id,
          :subj_type => 'Denotation'
        )
        @relations = Array.new
        @relations << @relation.get_hash
        @result = helper.bag_denotations(@denotations, @relations)
      end
      
      it 'denotations should be_blank' do
        @result[0][0].should eql({:id => "T1", :span => {:begin => 1 , :end => 5}, :obj => "Protein"})
      end
      
      it '' do
        @result[1][0].should eql(@relation.get_hash)
      end
    end
  end
  
  describe 'project_annotations_zip_link_helper' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :name => 'project_name', :annotations_updated_at => 1.day.ago)
    end
    
    context 'when downloadable = false' do
      before do
        @project.annotations_zip_downloadable = false
        @result = helper.project_annotations_zip_link_helper(@project)
      end
      
      it 'should return nil' do
        @result.should be_nil
      end
    end
    
    context 'when downloadable = true' do
      context 'when ZIP file exists' do
        before do
          File.stub(:exist?).and_return(true)
        end
        
        context 'when ZIP file is up-to-date' do
          before do
            File.stub(:ctime).and_return(DateTime.now)
            @result = helper.project_annotations_zip_link_helper(@project)
          end
          
          it 'should return ZIP file' do
            @result.should have_selector :a, :href => "/annotations/#{@project.name}.zip"
          end
          
          it 'should not return update ZIP file link' do
            @result.should_not have_selector :a, :href => project_annotations_path(@project.name, :delay => true, :update => true)
          end
        end
        
        context 'when ZIP file is not up-to-date' do
          before do
            File.stub(:ctime).and_return(2.days.ago)
            @result = helper.project_annotations_zip_link_helper(@project)
          end
          
          it 'should return ZIP file' do
            @result.should have_selector :a, :href => "/annotations/#{@project.name}.zip"
          end
          
          it 'should return update ZIP file link' do
            @result.should have_selector :a, :href => project_annotations_path(@project.name, :delay => true, :update => true)
          end
        end
      end
      
      context 'when delayed_job not exists' do
        before do
          @result = helper.project_annotations_zip_link_helper(@project)
        end
        
        it 'should return create ZIP link tag' do
          @result.should have_selector :a, :href => project_annotations_path(@project.name, :delay => true)
        end
      end
      
      context 'when delayed_job exists' do
        before do
          ActiveRecord::Base.connection.execute("INSERT INTO delayed_jobs ('attempts', 'created_at', 'failed_at', 'handler', 'last_error', 'locked_at', 'locked_by', 'priority', 'queue', 'run_at', 'updated_at') VALUES(1, 1, 0, '#{@project.name} save_annotation_zip', '', '', '', '', '', '', '') ")
          @result = helper.project_annotations_zip_link_helper(@project)
        end
        
        it 'should return message tells delayed job present' do
          @result.should eql(t('views.shared.zip.delayed_job_present'))
        end
      end
    end
  end

  describe 'annotations_url_helper' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => '123', :serial => 0)  
      assigns[:doc] = @doc
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))  
      assigns[:project] = @project 
      @begin = '5'
      @end = '10'
    end
    
    context 'when params[:div_id] present' do
      before do
        @div_id = '123'
      end
      
      context 'whern action == spans' do
        before do
          helper.stub(:params).and_return(:action => 'spans', :div_id => @div_id, :begin => @begin, :end => @end)  
        end
        
        it 'should return spans_annotations_project_sourcedb_sourceid_divs_docs_url' do
          helper.annotations_url_helper.should eql spans_annotations_project_sourcedb_sourceid_divs_docs_url(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial, @begin, @end)   
        end  
      end
      
      context 'whern action != spans' do
        before do
          helper.stub(:params).and_return(:action => 'doc', :div_id => @div_id)  
        end
        
        it 'should return spans_annotations_project_sourcedb_sourceid_divs_docs_url' do
          helper.annotations_url_helper.should eql annotations_project_sourcedb_sourceid_divs_docs_url(@project.name, @doc.sourcedb, @doc.sourceid, @doc.serial)   
        end  
      end
    end
    
    context 'when params[:div_id] blank' do
      context 'whern action == spans' do
        before do
          helper.stub(:params).and_return(:action => 'spans', :begin => @begin, :end => @end)  
        end
        
        it 'should return spans_annotations_project_sourcedb_sourceid_divs_docs_url' do
          helper.annotations_url_helper.should eql spans_annotations_project_sourcedb_sourceid_docs_url(@project.name, @doc.sourcedb, @doc.sourceid, @begin, @end)   
        end  
      end
      
      context 'whern action != spans' do
        before do
          helper.stub(:params).and_return(:action => 'doc')  
        end
        
        it 'should return spans_annotations_project_sourcedb_sourceid_divs_docs_url' do
          helper.annotations_url_helper.should eql annotations_project_sourcedb_sourceid_docs_url(@project.name, @doc.sourcedb, @doc.sourceid)   
        end  
      end
    end
  end
  
  describe 'annotations_form_action_helper' do
    before do
      @sourcedb = 'PMC'
      @sourceid = '123'
      @div_id = '123'
      @doc = FactoryGirl.create(:doc, sourcedb: @sourcedb, sourceid: @sourceid, serial: @div_id)
      assigns[:doc] = @doc
      @project_id = 'projectid'
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), name: @project_id)  
      assigns[:project] = @project      
    end
    
    context 'when params[:id] present' do
      before do
        helper.stub(:params).and_return(id: @doc.id)  
      end
      
      it 'should return create_annotatons_project_sourcedb_sourceid_divs_docs_path' do
        helper.annotations_form_action_helper.should eql annotations_project_doc_path(@project.name, @doc.id)
      end
    end
    
    context 'when params[:id] blank' do
      context 'when params[:div_id] present' do
        before do
          helper.stub(:params).and_return(project_id: @project_id, sourcedb: @sourcedb, sourceid: @sourceid, div_id: @div_id)  
        end
        
        it 'should return create_annotatons_project_sourcedb_sourceid_divs_docs_path' do
          helper.annotations_form_action_helper.should eql generate_annotatons_project_sourcedb_sourceid_divs_docs_path(@project_id, @sourcedb, @sourceid, @div_id)
        end
      end
      
      context 'when params[:div_id] blank' do
        before do
          @div_id = '123'
          helper.stub(:params).and_return(project_id: @project_id, sourcedb: @sourcedb, sourceid: @sourceid)  
        end
        
        it 'should return create_annotatons_project_sourcedb_sourceid_divs_docs_path' do
          helper.annotations_form_action_helper.should eql generate_annotatons_project_sourcedb_sourceid_docs_path(@project_id, @sourcedb, @sourceid)
        end
      end
    end
  end

  describe 'get_doc_info' do
    before do
      @source_db = 'sourcedb'
      @source_id = 'sourceid'
      @div_id = 3
      @section = 'section'
      @doc = FactoryGirl.create(:doc, sourcedb: @source_db, sourceid: @source_id, serial: @div_id, section: @section)
    end

    context 'when sourcedb sourceid divs section present' do
      before do
        @doc_info = helper.get_doc_info("/sourcedb/#{@source_db}/sourceid/#{@source_id}/divs/#{@div_id}")
      end

      it 'should return source_db, source_id, div_id and section' do
        @doc_info.should eql("#{@source_db}-#{@source_id}-#{@div_id}-#{@section}")
      end
    end

    context 'when sourcedb sourceid section present and divs(div_id) blank' do
      before do
        @doc_info = helper.get_doc_info("/sourcedb/#{@source_db}/sourceid/#{@source_id}")
      end

      it 'should return source_db and source_id' do
        @doc_info.should eql("#{@source_db}-#{@source_id}")
      end
    end

    context 'when sourcedb, sourceid and divs blank' do
      before do
        @doc_info = helper.get_doc_info(nil)
      end

      it 'should include source_db' do
        @doc_info.should eql("-") 
      end
    end
  end
end
