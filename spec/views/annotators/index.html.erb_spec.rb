require 'spec_helper'

describe "annotators/index" do
  before(:each) do
    assign(:annotators, [
      stub_model(Annotator,
        :abbrev => "Abbrev",
        :name => "Name",
        :description => "MyText",
        :home => "Home",
        :user => nil,
        :url => "Url",
        :params => "MyText",
        :method => 1,
        :url2 => "Url2",
        :params2 => "MyText",
        :method2 => 2
      ),
      stub_model(Annotator,
        :abbrev => "Abbrev",
        :name => "Name",
        :description => "MyText",
        :home => "Home",
        :user => nil,
        :url => "Url",
        :params => "MyText",
        :method => 1,
        :url2 => "Url2",
        :params2 => "MyText",
        :method2 => 2
      )
    ])
  end

  it "renders a list of annotators" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Abbrev".to_s, :count => 2
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "Home".to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Url".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => "Url2".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
