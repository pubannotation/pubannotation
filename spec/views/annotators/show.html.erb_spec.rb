require 'spec_helper'

describe "annotators/show" do
  before(:each) do
    @annotator = assign(:annotator, stub_model(Annotator,
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
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Abbrev/)
    rendered.should match(/Name/)
    rendered.should match(/MyText/)
    rendered.should match(/Home/)
    rendered.should match(//)
    rendered.should match(/Url/)
    rendered.should match(/MyText/)
    rendered.should match(/1/)
    rendered.should match(/Url2/)
    rendered.should match(/MyText/)
    rendered.should match(/2/)
  end
end
