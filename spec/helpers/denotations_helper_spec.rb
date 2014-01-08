# encoding: utf-8
require 'spec_helper'

describe DenotationsHelper do
  describe 'denotations_count_helper' do
    before do
      @project_denotations_count = 'project_denotations_count'
      Denotation.stub!(:project_denotations_count) do |project_id, denotations|
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
      @begin = 22
      @end = 33
      @denotation = {:span => {:begin => @begin, :end => @end}}
      @id = 11
      @pmcdoc_id = 44
    end
    
    context 'when params[:project_id] present' do
      before do
        @project_id = 55
      end
      
      context 'when controller == pmdocs' do
        before do
          helper.stub(:params).and_return({
            :controller => 'pmdocs',
            :project_id => @project_id,
            :id => @id
          })
          @result = helper.spans_link_helper(@denotation)
        end
        
        it 'should return project pmdoc spans url' do
          @result.should have_selector :a, :href => "/projects/#{@project_id}/pmdocs/#{@id}/spans/#{@begin}-#{@end}"
        end        
      end
      
      context 'when params[:pmdoc_id] present' do
        before do
          helper.stub(:params).and_return({
            :controller => 'annotations',
            :project_id => @project_id,
            :pmdoc_id => @id
          })
          @result = helper.spans_link_helper(@denotation)
        end
        
        it 'should return project pmdoc spans url' do
          @result.should have_selector :a, :href => "/projects/#{@project_id}/pmdocs/#{@id}/spans/#{@begin}-#{@end}"
        end        

      end
      
      describe 'divs#spans or annotaitons#index' do
        context 'when controller == pmcdocs' do
          before do
            helper.stub(:params).and_return({
              :controller => 'divs',
              :project_id => @project_id,
              :pmcdoc_id => @pmcdoc_id,
              :id => @id
            })
            @result = helper.spans_link_helper(@denotation)
          end
          
          it 'should return project pmdoc spans url' do
            @result.should have_selector :a, :href => "/projects/#{@project_id}/pmcdocs/#{@pmcdoc_id}/divs/#{@id}/spans/#{@begin}-#{@end}"
          end        
        end
        
        context 'when params[:pmdoc_id] present' do
          before do
            helper.stub(:params).and_return({
              :controller => 'annotations',
              :project_id => @project_id,
              :pmcdoc_id => @pmcdoc_id,
              :div_id => @id
            })
            @result = helper.spans_link_helper(@denotation)
          end
          
          it 'should return project pmdoc spans url' do
            @result.should have_selector :a, :href => "/projects/#{@project_id}/pmcdocs/#{@pmcdoc_id}/divs/#{@id}/spans/#{@begin}-#{@end}"
          end        
        end
      end
    end

    describe 'when params[:project_id] blank' do
      context 'when controller == pmdocs' do
        before do
          helper.stub(:params).and_return({
            :controller => 'pmdocs',
            :id => @id
          })
          @result = helper.spans_link_helper(@denotation)
        end
        
        it 'should return pmdoc spans url' do
          @result.should have_selector :a, :href => "/pmdocs/#{@id}/spans/#{@begin}-#{@end}"
        end        
      end      

      context 'when controller == pmcdocs' do
        before do
          helper.stub(:params).and_return({
            :controller => 'divs',
            :pmcdoc_id => @pmcdoc_id,
            :id => @id
          })
          @result = helper.spans_link_helper(@denotation)
        end
        
        it 'should return project pmdoc spans url' do
          @result.should have_selector :a, :href => "/pmcdocs/#{@pmcdoc_id}/divs/#{@id}/spans/#{@begin}-#{@end}"
        end        
      end     
    end
  end
end