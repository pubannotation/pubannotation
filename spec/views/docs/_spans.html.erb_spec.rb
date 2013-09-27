# encoding: utf-8
require 'spec_helper'

describe "docs/_span.html.erb" do
  before do
    @spans = 'this is spans'
    @doc = FactoryGirl.create(:doc, 
    :sourcedb => 'sourcedb', 
    :sourceid => 'sourceid',
    :source => 'http://www.to')
    assign :doc, @doc
    assign :spans, @spans
    render
  end
  
  it 'should render @spans' do
    rendered.should include(@spans)
  end
end