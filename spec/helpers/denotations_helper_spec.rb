# encoding: utf-8
require 'spec_helper'

describe DenotationsHelper do
  describe 'denotations_count_helper' do
    before do
      @project_denotations_count = 'project_denotations_count'
      Denotation.stub(:project_denotations_count) do |project_id, denotations|
        [project_id, denotations, @project_denotations_count]
      end
      @project = FactoryGirl.create(:project, :relations_count => 100)
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when params[:action] == spans' do
      context 'when project.present?' do
        before do
          @begin = 0
          @end = 10
          @denotation_project_1_1 = FactoryGirl.create(:denotation, :project_id => 1, :begin => @begin, :end => @end)
          @denotation_project_1_2 = FactoryGirl.create(:denotation, :project_id => 1, :begin => @begin, :end => @end)
          @denotation_project_2 = FactoryGirl.create(:denotation, :project_id => 2, :begin => @begin, :end => @end)
          @within_spans = [@denotation_project_1_1, @denotation_project_1_2, @denotation_project_2]
          helper.stub(:params).and_return({:action => 'spans', :begin => @begin, :end => @end})
          @result = helper.denotations_count_helper(@project, {:doc => @doc, :sourceid => 'sourceid'})
        end
        
        it 'should return denotations.within_spans which belongs to project size' do
          @result.should eql(2)
        end 
      end

      context 'when project.blank?' do
        before do
          helper.stub(:params).and_return({:action => 'spans'})
          @within_spans = [1, 2, 3]
          Denotation.stub(:within_spans).and_return(@within_spans)
          @result = helper.denotations_count_helper(nil, {:doc => @doc, :sourceid => 'sourceid'})
        end
        
        it 'should return denotations.within_spans.size' do
          @result.should eql(@within_spans.size)
        end  
      end
    end
    
    context 'when params[:action] != spans' do
      context 'when project present' do
        before do
          @doc_denotations = 'denotations'
          Doc.any_instance.stub(:denotations).and_return(@doc_denotations)
          @project_pmcdoc_denotations = [1, 2 , 3]
          Denotation.stub(:project_pmcdoc_denotations).and_return(@project_pmcdoc_denotations)
        end
        
        context 'when doc present' do
          context 'when controller == projects' do
            before do
              @doc.sourcedb = 'PMC'
              helper.stub(:params).and_return({:controller => 'projects'})
              @result = helper.denotations_count_helper(@project, {:doc => @doc})
            end
            
            it 'denotations should be project.denotations.project_pmcdoc_denotations(options[:sourceid]).count' do
              @result.should eql(@project_pmcdoc_denotations.size)
            end
          end
          
          context 'when controller == divs' do
            before do
              @result = helper.denotations_count_helper(@project, {:doc => @doc})
            end
            
            it 'denotations should be doc.denotations' do
              @result[1].should eql(@doc_denotations)
            end
            
            it 'denotations should be returned Denotation.project_denotations_count' do
              @result[2].should eql(@project_denotations_count)
            end
          end
        end
  
        context 'when doc blank' do
          before do
            @result = helper.denotations_count_helper(@project)
          end
          
          it 'denotations should be project.denotations_count' do
            @result.should eql(@project.denotations_count)
          end
        end
      end
        
      context 'when project blank' do
        before do
          @doc_denotations_size = 'doc_denotations_size'
          Doc.any_instance.stub(:denotations).and_return(double(:size => @doc_denotations_size))
          @result = helper.denotations_count_helper(nil, {:doc => @doc})
        end
        
        it 'should return doc.denotations.size' do
          @result.should eql(@doc_denotations_size)
        end
      end
    end
  end
  
  describe 'spans_link_helper' do
    before do
      @doc = FactoryGirl.create(:doc)
      @denotation = {:span => {:begin => 0, :end => 10}}  
    end

    context 'when doc has_divs? = true' do
      before do 
        @doc.stub(:has_divs?).and_return(true)
      end

      it 'should return divs_spans_path link tag' do
        helper.spans_link_helper(@denotation).should have_selector(:a, href: doc_sourcedb_sourceid_divs_spans_path(@doc.sourcedb, @doc.sourceid, @doc.serial, @denotation[:span][:begin], @denotation[:span][:end]))
      end
    end

    context 'when doc has_divs? = false' do
      before do 
        @doc.stub(:has_divs?).and_return(false)
      end

      it 'should return divs_spans_path link tag' do
        helper.spans_link_helper(@denotation).should have_selector(:a, href: doc_sourcedb_sourceid_spans_path(@doc.sourcedb, @doc.sourceid,  @denotation[:span][:begin], @denotation[:span][:end]))
      end
    end
  end
end
