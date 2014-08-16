# encoding: utf-8
require 'spec_helper'

describe "docs/_form.html.erb" do
  before do
    assign :doc, Doc.new
    @current_user = FactoryGirl.create(:user)
    view.stub(:current_user).and_return(@current_user)
    render
  end

  it 'should render doc[username]' do
    rendered.should have_selector :input, name: 'doc[username]', type: 'hidden', value: @current_user.username 
  end
end
