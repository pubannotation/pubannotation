# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    let(:current_user ) { FactoryGirl.create(:user) }
    let(:news_notifications_limit) { 'news_notifications_limit' }
    let(:visit_log_top) { 'visit_log_top' }

    before do
      current_user_stub(current_user)
      NewsNotification.stub(:limit).and_return(news_notifications_limit)
      VisitLog.stub(:top).and_return(visit_log_top)
      get :index
    end

    it 'should assign NewsNotification.limit as @news_notifications' do
      expect( assigns[:news_notifications] ).to eql( news_notifications_limit) 
    end

    it 'should assign VisitLog.top as @visit_logs' do
      expect( assigns[:visit_logs] ).to eql(VisitLog.top)
    end
  end
end
