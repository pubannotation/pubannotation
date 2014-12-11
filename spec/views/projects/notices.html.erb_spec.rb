# encoding: utf-8
require 'spec_helper'

describe "projects/notices.html.erb" do
  before do
    assign :doc, FactoryGirl.create(:doc)
    assign :project, FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    view.stub(:notices_list_helper).and_return(nil)
  end

  it 'should call notices_list_helper' do
    view.should_receive(:notices_list_helper)
    render
  end
end
