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
    
    
    context 'when project present' do
      context 'when sourceid present' do
        before do
          @same_sourceid_denotations_count = 'same_sourceid_denotations_count'
          Doc.any_instance.stub(:same_sourceid_denotations_count).and_return(@same_sourceid_denotations_count)
          @result = helper.denotations_count_helper(@project, @doc, 'sourceid')
        end
        
        it 'should return doc.same_sourceid_denotations_count' do
          @result.should eql(@same_sourceid_denotations_count)
        end
      end
      
      context 'when sourceid nil' do
        before do
          @doc_denotations = 'denotations'
          Doc.any_instance.stub(:denotations).and_return(@doc_denotations)
        end
        
        context 'when doc present' do
          before do
            @result = helper.denotations_count_helper(@project, @doc)
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
    end
      
    context 'when project blank' do
      before do
        @doc_denotations_size = 'doc_denotations_size'
        Doc.any_instance.stub(:denotations).and_return(double(:size => @doc_denotations_size))
        @result = helper.denotations_count_helper(nil, @doc)
      end
      
      it 'should return doc.denotations.size' do
        @result.should eql(@doc_denotations_size)
      end
    end
  end
end