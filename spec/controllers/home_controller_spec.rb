# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    let(:current_user ) { FactoryGirl.create(:user) }
    let(:news_notifications_limit) { 'news_notifications_limit' }

    before do
      current_user_stub(current_user)
      NewsNotification.stub(:limit).and_return(news_notifications_limit)
      get :index
    end

    it 'shoould assign NewsNotification.limit as @news_notifications' do
      expect( assigns[:news_notifications] ).to eql( news_notifications_limit) 
    end
  end
end
