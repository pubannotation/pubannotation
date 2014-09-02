# encoding: utf-8
require 'spec_helper'

describe "annotations/annotations.html.erb" do
  before do
    @docs_path = 'docs/path'
    stub_template 'docs/_path' => @docs_path
    @shared_textae_css_js = 'shared/_textae_css_js'
    stub_template 'shared/_textae_css_js' => @shared_textae_css_js
    stub_template 'annotations/_project_textae.erb' => "<%= project_textae.name %>"
  end

  context 'when @project_denotations include some projects' do
    before do
      assign :project_denotations, [double(name: 'First'), double(name: 'Second')] 
      render
    end

    it 'shoud render doct/path' do
      rendered.should include(@docs_path)
    end

    it 'shoud render shared/textae_css_js' do
      rendered.should include(@shared_textae_css_js)
    end

    it 'shoud render project_textae with collection @project_denotations' do
      expect(rendered).to match /First/
      expect(rendered).to match /Second/
    end
  end

  context 'when @project_denotations include only one project' do
    before do
      assign :project_denotations, [double(name: 'Only')] 
      render
    end

    it 'shoud render project_textae with collection @project_denotations' do
      expect(rendered).to match /Only/
    end
  end
end
