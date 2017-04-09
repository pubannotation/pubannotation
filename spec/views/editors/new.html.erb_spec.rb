require 'spec_helper'

describe "editors/new" do
  before(:each) do
    assign(:editor, stub_model(Editor,
      :name => "MyString",
      :url => "MyString",
      :parameters => "MyText",
      :description => "MyText",
      :home => "MyString",
      :user => nil,
      :is_public => false
    ).as_new_record)
  end

  it "renders new editor form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", editors_path, "post" do
      assert_select "input#editor_name[name=?]", "editor[name]"
      assert_select "input#editor_url[name=?]", "editor[url]"
      assert_select "textarea#editor_parameters[name=?]", "editor[parameters]"
      assert_select "textarea#editor_description[name=?]", "editor[description]"
      assert_select "input#editor_home[name=?]", "editor[home]"
      assert_select "input#editor_user[name=?]", "editor[user]"
      assert_select "input#editor_is_public[name=?]", "editor[is_public]"
    end
  end
end
