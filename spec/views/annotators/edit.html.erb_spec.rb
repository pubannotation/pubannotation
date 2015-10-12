require 'spec_helper'

describe "annotators/edit" do
  before(:each) do
    @annotator = assign(:annotator, stub_model(Annotator,
      :abbrev => "MyString",
      :name => "MyString",
      :description => "MyText",
      :home => "MyString",
      :user => nil,
      :url => "MyString",
      :params => "MyText",
      :method => 1,
      :url2 => "MyString",
      :params2 => "MyText",
      :method2 => 1
    ))
  end

  it "renders the edit annotator form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", annotator_path(@annotator), "post" do
      assert_select "input#annotator_abbrev[name=?]", "annotator[abbrev]"
      assert_select "input#annotator_name[name=?]", "annotator[name]"
      assert_select "textarea#annotator_description[name=?]", "annotator[description]"
      assert_select "input#annotator_home[name=?]", "annotator[home]"
      assert_select "input#annotator_user[name=?]", "annotator[user]"
      assert_select "input#annotator_url[name=?]", "annotator[url]"
      assert_select "textarea#annotator_params[name=?]", "annotator[params]"
      assert_select "input#annotator_method[name=?]", "annotator[method]"
      assert_select "input#annotator_url2[name=?]", "annotator[url2]"
      assert_select "textarea#annotator_params2[name=?]", "annotator[params2]"
      assert_select "input#annotator_method2[name=?]", "annotator[method2]"
    end
  end
end
