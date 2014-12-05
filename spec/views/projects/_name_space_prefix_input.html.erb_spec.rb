# encoding: utf-8
require 'spec_helper'

describe "projects/_namespace_prefix_input.html.erb" do  
  context 'when collection blank' do
    before do
      view.stub(:namespace_prefix_input).and_return(nil)
      render
    end

    it 'should render input text without prefix value' do
      rendered.should have_selector(:input, type: 'text', name: 'project[namespaces][][prefix]')
    end

    it 'should render input text with uri value' do
      rendered.should have_selector(:input, type: 'text', name: 'project[namespaces][][uri]')
    end
  end

  context 'when collection prensent' do
    before do
      @prefix = {'prefix' => 'prefix', 'uri' => 'http://uri.to'}
      view.stub(:namespace_prefix_input).and_return(@prefix)
      render
    end

    it 'should render input text with prefix value' do
      rendered.should have_selector(:input, value: @prefix['prefix'], type: 'text', name: 'project[namespaces][][prefix]')
    end

    it 'should render input text with uri value' do
      rendered.should have_selector(:input, value: @prefix['uri'], type: 'text', name: 'project[namespaces][][uri]')
    end
  end
end
