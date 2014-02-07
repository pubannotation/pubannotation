# encoding: utf-8
require 'spec_helper'

describe "divs/index.html.erb" do
  describe 'counts' do
    before do
      assign :docs, [FactoryGirl.create(:doc, :body => 'body', :sourceid => 'sourceid', :serial => 0)]
      @project = FactoryGirl.create(:project)
      assign :project, @project
      assign :project_name, @project.name
      @denotations_count_helper = 'denotations_count_helper'
      view.stub(:denotations_count_helper).and_return(@denotations_count_helper)
      @relations_count_helper = 'relations_count_helper'
      view.stub(:relations_count_helper).and_return(@relations_count_helper)
      view.stub(:params).and_return({:pmcdoc_id => 1})
      render
    end
    
    it 'should render denotations_count_helper' do
      rendered.should include(@denotations_count_helper)
    end
    
    it 'should render relations_count_helper' do
      rendered.should include(@relations_count_helper)
    end
  end
end