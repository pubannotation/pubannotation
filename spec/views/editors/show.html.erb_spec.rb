require 'spec_helper'

describe "editors/show" do
  before(:each) do
    @editor = assign(:editor, stub_model(Editor,
      :name => "Name",
      :url => "Url",
      :parameters => "MyText",
      :description => "MyText",
      :home => "Home",
      :user => nil,
      :is_public => false
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/Url/)
    rendered.should match(/MyText/)
    rendered.should match(/MyText/)
    rendered.should match(/Home/)
    rendered.should match(//)
    rendered.should match(/false/)
  end
end
