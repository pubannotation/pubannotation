# encoding: utf-8
require 'spec_helper'

describe DocsHelper do
  describe 'sourceid_index_link_helper' do
    before do
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb')
      @project_id = 'project_id' 
    end
    
    context 'when params[:project_id] present' do
      before do
        helper.stub(:params).and_return({:project_id => @project_id})
        @result = helper.sourceid_index_link_helper(@doc)
      end
      
      it 'should return project  sourceid index link' do
        @result.should have_selector :a, :href => sourceid_index_project_sourcedb_docs_path(@project_id, @doc.sourcedb)
      end
    end
    
    context 'when params[:project_id] blank' do
      before do
        @result = helper.sourceid_index_link_helper(@doc)
      end
      
      it 'should return sourceid index link' do
        @result.should have_selector :a, :href => doc_sourcedb_sourceid_index_path(@doc.sourcedb)
      end
    end
  end
  
  describe 'source_db_index_docs_count_helper' do
    before do
      @doc = FactoryGirl.create(:doc, sourcedb: 'sourcedb', sourceid: 'sourceid')
      @docs = ''
    end
    
    context 'when count.class == Fixnum' do
      before do
        @count = 5
        @docs.stub(:same_sourcedb_sourceid).and_return(double(count: @count))
        @result = source_db_index_docs_count_helper(@docs, @doc)
      end
      
      it 'should rerutn ' do
        @result.should eql("(#{@count})")
      end
    end
    
    context 'when count.class != Fixnum' do
      before do
        @count = '5'
        @docs.stub(:same_sourcedb_sourceid).and_return(double(count: {[] => @count}))
        @result = source_db_index_docs_count_helper(@docs, @doc)
      end
      
      it 'should rerutn ' do
        @result.should eql("(#{@count})")
      end
    end
  end

  describe 'sourcedb_options_for_select' do
    before do
      ['A', 'B'].each do |sourcedb|
        FactoryGirl.create(:doc, sourcedb: sourcedb) 
      end
    end

    it 'should return sourcedb array' do
      helper.sourcedb_options_for_select.should =~ [['A', 'A'], ['B', 'B']]
    end
  end

  describe 'json_text_link_helper' do
    context 'when div' do
      context 'when action == div_annotations_visualize' do
        let(:params) { {project: 'project', projects: ['project_1', 'project_2'], sourcedb: 'FA', sourceid: '8424', divid: '0', action: 'div_annotations_visualize'} }

        before do
          helper.stub(:params).and_return(params)
        end

        it 'should return a tag with href for divs#show for json' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], params[:divid], format: :json) )
        end

        it 'should return a tag with href for divs#show for txt' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], params[:divid], format: :txt) )
        end
      end

      context 'when action != div_annotations_visualize' do
        let(:params) { {project: 'project', projects: 'project_1,project_2', sourcedb: 'FA', sourceid: '8424', divid: '0', action: 'div_annotations_index'} }

        before do
          helper.stub(:params).and_return(params)
        end

        it 'should return a tag with href for divs#show for json with params[:project] and params[:projects]' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], params[:divid], project: params[:project], projects: params[:projects], format: :json) )
        end

        it 'should return a tag with href for divs#show for txt with params[:project] and params[:projects]' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], params[:divid], project: params[:project], projects: params[:projects], format: :txt) )
        end
      end
    end

    context 'when doc' do
      context 'when action == doc_annotations_visualize' do
        let(:params) { {project: 'project', projects: ['project_1', 'project_2'], sourcedb: 'FA', sourceid: '8424', action: 'doc_annotations_visualize'} }

        before do
          helper.stub(:params).and_return(params)
        end

        it 'should return a tag with href for docs#show for json' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid], format: :json) )
        end

        it 'should return a tag with href for docs#show for txt' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid], format: :txt) )
        end
      end

      context 'when action != doc_annotations_visualize' do
        let(:params) { {project: 'project', projects: 'project_1,project_2', sourcedb: 'FA', sourceid: '8424', action: 'div_annotations_index'} }

        before do
          helper.stub(:params).and_return(params)
        end

        it 'should return a tag with href for divs#show for json with params[:project] and params[:projects]' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid], project: params[:project], projects: params[:projects], format: :json) )
        end

        it 'should return a tag with href for divs#show for txt with params[:project] and params[:projects]' do
          expect( helper.json_text_link_helper ).to have_selector(:a, :href => doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid], project: params[:project], projects: params[:projects], format: :txt) )
        end
      end
    end
  end
end 
