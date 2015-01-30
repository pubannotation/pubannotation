# encoding: utf-8
require 'spec_helper'

describe "annotations/_summary_and_view_options.html.erb" do
  before do
    @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    assign :project, @project
    @doc = FactoryGirl.create(:doc)
    assign :doc, @doc
  end

  describe 'visualization_link' do
    it 'should call visualization_link' do
      view.should_receive(:visualization_link)
      render
    end
  end
end
