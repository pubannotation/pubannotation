# encoding: utf-8
require 'spec_helper'

describe RelationsHelper do
  describe 'relations_count_helper' do
    before do
      @relation_project_relations_count = 'project_relations_count'
      Relation.stub(:project_relations_count).and_return(@relation_project_relations_count)
      @doc_project_relations_count = 'doc_project_relations_count'
      Doc.any_instance.stub(:project_relations_count).and_return(@doc_project_relations_count)
      @doc_relations_count = 'doc_relations_count'
      Doc.any_instance.stub(:relations_count).and_return(@doc_relations_count)
      @same_sourceid_relations_count = 'same_sourceid_relations_count'
      Doc.any_instance.stub(:same_sourceid_relations_count).and_return(@same_sourceid_relations_count)
      @project = FactoryGirl.create(:project)
      @doc = FactoryGirl.create(:doc)
    end
    
    context 'when params[:action] == spans' do
      before do
        helper.stub(:params).and_return({:action => 'spans'})
        @hrelations = [1,2,3]
        Doc.any_instance.stub(:hrelations).and_return(@hrelations)
        @result = helper.relations_count_helper(@project, {:doc => @doc, :sourceid => 'sourceid'})
      end
      
      it 'should return @doc.hrelations.size' do
        @result.should eql(@hrelations.size)
      end  
    end
        
    context 'when project present' do
      context 'when doc present' do
        before do
          @result = helper.relations_count_helper(@project, {:doc => @doc})
        end
        
        it 'should return Relation.project_relations_count' do
          @result.should eql(@doc_project_relations_count)
        end
      end

      context 'when doc blank' do
        context 'when project.class == Project' do
          before do
            @result = helper.relations_count_helper(@project)
          end
          
          it 'should return Relation.project_relations_count' do
            @result.should eql(@relation_project_relations_count)
          end
        end
      end
    end
    
    context 'when project blank' do
      before do
        @result = helper.relations_count_helper(nil, {:doc => @doc})
      end
      
      it 'should return doc.relations_count' do
        @result.should eql(@doc_relations_count)
      end
    end
  end
end