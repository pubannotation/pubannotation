# encoding: utf-8
require 'spec_helper'

describe "docs/_span.html.erb" do
  before do
    @spans = 'this is spans'
    @highlight_text = "this is <span>spans</span>"
    @doc = FactoryGirl.create(:doc, 
    :sourcedb => 'sourcedb', 
    :sourceid => 'sourceid',
    :source => 'http://www.to')
    assign :doc, @doc
    assign :spans, @spans
    assign :highlight_text, @highlight_text
    render
  end
  
  it 'should render @spans' do
    rendered.should include(@highlight_text)
  end
end