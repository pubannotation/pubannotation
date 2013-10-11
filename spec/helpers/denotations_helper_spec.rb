# encoding: utf-8
require 'spec_helper'

describe DenotationsHelper do
  describe 'denotations_count_helper' do
    before do
      Denotation.stub!(:project_denotations_count) do |project_id, denotations|
        [project_id, denotations]
      end
      @project = FactoryGirl.create(:project)
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
    
    context 'when project present' do
      context 'when sourceid present' do
        before do
          @same_sourceid_denotations_count = 'same_sourceid_denotations_count'
          Doc.any_instance.stub(:same_sourceid_denotations_count).and_return(@same_sourceid_denotations_count)
          @result = helper.denotations_count_helper(@project, {:doc => @doc, :sourceid => 'sourceid'})
        end
        
        it 'should return doc.same_sourceid_denotations_count' do
          @result.should eql(@same_sourceid_denotations_count)
        end
      end
      
      context 'when sourceid nil' do
        context 'when project.class == Project' do
          before do
            @doc_denotations = 'denotations'
            Doc.any_instance.stub(:denotations).and_return(@doc_denotations)
          end
          
          context 'when doc present' do
            before do
              @result = helper.denotations_count_helper(@project, {:doc => @doc})
            end
            
            it 'denotations should be doc.denotations' do
              @result[1].should eql(@doc_denotations)
            end
          end
    
          context 'when doc blank' do
            before do
              @result = helper.denotations_count_helper(@project)
            end
            
            it 'denotations should be Denotation class' do
              @result[1].should eql(Denotation)
            end
          end
        end

        context 'when project.class != Project' do
          before do
            @sproject_denotaions_count = 'Sproject denotations count'
            @sproject = FactoryGirl.create(:sproject, :denotations_count => 15)
            @result = helper.denotations_count_helper(@sproject)
          end
          
          it 'should return sproejct.denotations_count' do
            @result.should eql(@sproject.denotations_count)
          end
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