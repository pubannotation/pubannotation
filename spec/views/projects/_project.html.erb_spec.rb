# encoding: utf-8
require 'spec_helper'

describe "projects/_project.html.erb" do  
  describe 'accordion' do
    before do
      @project = FactoryGirl.create(:project)
      view.stub(:user_signed_in?).and_return(false)
      view.stub(:current_user).and_return(nil)
    end
  end
end