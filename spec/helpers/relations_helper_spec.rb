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
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user), :relations_count => 100)
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
        context 'when controller = projects' do
          before do
            @doc.sourcedb = 'PMC'
            helper.stub(:params).and_return({:controller => 'projects'})
            @project_pmcdoc_cat_relations = [1, 2]
            Relation.stub(:project_pmcdoc_cat_relations).and_return(@project_pmcdoc_cat_relations)
            @project_pmcdoc_ins_relations = [1, 2, 3]
            Relation.stub(:project_pmcdoc_ins_relations).and_return(@project_pmcdoc_ins_relations)
            @result = helper.relations_count_helper(@project, {:doc => @doc})
          end
          
          it 'should return project.relations project_pmcdoc_cat_relations.count + project_pmcdoc_ins_relations.count' do
            @result.should eql(@project_pmcdoc_cat_relations.count + @project_pmcdoc_ins_relations.count)
          end
        end
        
        context 'when controller = divs' do
          before do
            @result = helper.relations_count_helper(@project, {:doc => @doc})
          end
          
          it 'should return Relation.project_relations_count' do
            @result.should eql(@doc_project_relations_count)
          end
        end
      end

      context 'when doc blank' do
        context 'when project.class == Project' do
          before do
            @result = helper.relations_count_helper(@project)
          end
          
          it 'should return Relation.project_relations_count' do
            @result.should eql(@project.relations_count)
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
