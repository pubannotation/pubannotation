# encoding: utf-8
require 'spec_helper'

describe "docs/_titlebar.html.erb" do
  let(:json_text_link) { 'json_text_link' }

  before do
    @doc = FactoryGirl.create(:doc, sourcedb: 'sourcedb', sourceid: 'sourceid', source: 'http://www.to')
    view.stub(:json_text_link_helper).and_return(json_text_link)
  end

  describe 'json_text_link_helper' do
    before do
      render
    end

    it 'should render json_text_link_helper' do
      rendered.should include(json_text_link)
    end
  end
end
