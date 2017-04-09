require 'spec_helper'

describe "editors/index" do
  before(:each) do
    assign(:editors, [
      stub_model(Editor,
        :name => "Name",
        :url => "Url",
        :parameters => "MyText",
        :description => "MyText",
        :home => "Home",
        :user => nil,
        :is_public => false
      ),
      stub_model(Editor,
        :name => "Name",
        :url => "Url",
        :parameters => "MyText",
        :description => "MyText",
        :home => "Home",
        :user => nil,
        :is_public => false
      )
    ])
  end

  it "renders a list of editors" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Url".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "Home".to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => false.to_s, :count => 2
  end
end
