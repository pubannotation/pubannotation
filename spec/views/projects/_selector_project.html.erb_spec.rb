# encoding: utf-8
require 'spec_helper'

describe "projects/_selector_project.html.erb" do
  let(:selector_project) { FactoryGirl.create(:project, user: FactoryGirl.create(:user)) }
  let(:annotations_count_helper) { 'annotations_count_helper' }
  let(:annotations_path) { 'annotations_path' }

  before do
    view.stub(:selector_project).and_return(selector_project)
    view.stub(:annotations_count_helper).and_return(annotations_count_helper)
    view.stub(:annotations_path).and_return(annotations_path)
    render
  end

  it 'should render data-annotations-count with annotations_count_helper' do
    expect(rendered).should have_selector(:span, 'data-annotations-count' => annotations_count_helper)
  end

  it 'should render data-project-name with selector_project.name' do
    expect(rendered).should have_selector(:span, 'data-project-name' => selector_project.name)
  end

  it 'should render link to selector_project' do
    expect(rendered).should have_selector(:a, href: project_path(selector_project.name))
  end

  it 'should render annotations_count' do
    expect(rendered).to match /"(#{annotations_count_helper})"/
  end


  it 'should render id with selector_project.name' do
    expect(rendered).should have_selector(:span, id: "project-selector-#{selector_project.name}")
  end

  it 'should render data-project-url with selector_project' do
    expect(rendered).should have_selector(:span, 'data-project-url' => project_path(selector_project.name))
  end

  it 'should render data-project-name with selector_project.name' do
    expect(rendered).should have_selector(:span, 'data-project-name' => selector_project.name)
  end

  it 'should render data-project-id with selector_project.id' do
    expect(rendered).should have_selector(:span, 'data-project-id' => selector_project.id.to_s)
  end

  it 'should render data-annotations-json-url with annotations_path' do
    expect(rendered).should have_selector(:span, 'data-annotations-json-url' => "#{annotations_path}.json")
  end
end
