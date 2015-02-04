# encoding: utf-8
require 'spec_helper'

describe "docs/spans.html.erb" do
  before do
    @annotations_path = '/annotations'
    assign  :annotations_path, @annotations_path
    # view.stub_chain(:render, :partial).and_return(nil)
    doc = FactoryGirl.create(:doc)
    assign :doc, doc
    project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    assign :projects, [project]
    @template_docs_path = 'docs/_path'
    stub_template 'docs/_path' => @template_docs_path
    @template_docs_span = 'docs/_span'
    stub_template 'docs/_span' => @template_docs_span
    @template_annotations_summary = 'projects/_list'
    stub_template 'annotations/_summary_and_view_options' => @template_annotations_summary
    @template_projects_list = 'projects/_list'
    stub_template 'projects/_list' => @template_projects_list
    view.stub(:visualization_link).and_return(nil)
  end

  context 'when params[:project_id] is present' do
    before do
      view.stub(:params).and_return({project_id: '1'})
      render
    end

    # check at once
    it 'should render partial template docs/path' do
      rendered.should include(@template_docs_path)
    end

    # check at once
    it 'should render partial template docs/span' do
      rendered.should include(@template_docs_span)
    end

    it 'should render annotations/summary_and_view_options' do
      rendered.should include(@template_annotations_summary)
    end

    it 'should_not call visualization_link' do
      expect(view).not_to receive(:visualization_link)
      render
    end
  end

  context 'when params[:project_id] is blank' do
    before do
      render
    end

    it 'should render @annotations_path' do
      rendered.should include(@annotations_path)
    end

    it 'should render partial template projects/list' do
      rendered.should include(@template_projects_list)
    end

    it 'should call visualization_link' do
      expect(view).to receive(:visualization_link)
      render
    end
  end
end
