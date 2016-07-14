# encoding: utf-8
require 'spec_helper'

describe NewsNotificationsController do
  before do
    controller.class.skip_before_filter :is_root_user?
  end

  describe 'index' do
    let(:news_notifications) { 'news_notifications' }

    before do
      NewsNotification.stub(:limit).and_return(news_notifications)
      get :index
    end

    it 'should set NewsNotification.limit as @news_notifications' do
      expect(assigns[:news_notifications]).to eql(news_notifications)
    end

    it 'shoould render template' do
      expect(response).to render_template(:index)
    end
  end

  describe 'category' do
    let(:general_news_1) { FactoryGirl.create(:news_notification, category: 'general') }
    let(:general_news_2) { FactoryGirl.create(:news_notification, category: 'general') }
    let(:system_update) { FactoryGirl.create(:news_notification, category: 'system_update') }

    context 'when category exists' do
      before do
        get :category, category: 'general'
      end

      it 'should set news_notifications by category as @news_notifications' do
        expect(assigns[:news_notifications]).to match_array([general_news_1, general_news_2])
      end

      it 'should render template' do
        expect(response).to render_template(:category)
      end
    end

    context 'when no category news_notifications' do
      before do
        get :category, category: 'not_match'
      end

      it 'should set news_notifications by category as @news_notifications' do
        expect(assigns[:news_notifications]).to be_blank
      end

      it 'should set flash[:notice]' do
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe 'new' do
    before do
      get :new
    end
  
    it 'should assign new_record as @news_notifications' do
      expect(assigns[:news_notification]).to be_a_new(NewsNotification)
    end

    it 'should render template' do
      expect(response).to render_template(:new)
    end
  end

  describe 'create' do
    context 'when successfully saved' do
      let(:news_notification) { {title: 'Title', body: 'News body'} }
      let(:subject) { post :create, news_notification: news_notification }  

      it 'should create a news_notification' do
        expect{ subject }.to change{ NewsNotification.count }.by(1)
      end

      it 'should create a news_notification' do
        expect( subject ).to redirect_to( assigns[:news_notification] )
      end
    end

    context 'when not saved' do
      let(:news_notification) { {title: 'Title'} }

      it 'should not create a news_notification' do
        expect{ post :create, news_notification: news_notification }.to change{ NewsNotification.count }.by(0)
      end

      it 'should render template' do
        post :create, news_notification: news_notification
        expect( response ).to render_template(:new)
      end
    end
  end

  describe 'show' do
    let(:news_notification) { FactoryGirl.create(:news_notification) }

    before do
      get :show, id: news_notification.id
    end
  
    it 'should @news_notifications' do
      expect(assigns[:news_notification]).to eql(news_notification)
    end

    it 'should render template' do
      expect( response ).to render_template(:show)
    end
  end

  describe 'edit' do
    let(:news_notification) { FactoryGirl.create(:news_notification) }

    before do
      get :edit, id: news_notification.id
    end
  
    it 'should @news_notifications' do
      expect(assigns[:news_notification]).to eql(news_notification)
    end

    it 'should render template' do
      expect( response ).to render_template(:edit)
    end
  end

  describe 'update' do
    let(:news_notification) { FactoryGirl.create(:news_notification) }

    context 'when update successfully' do
      let(:update_news_notification) { { title: 'new updated title', body: 'new updated body' } }
      let(:subject) { post :update, id: news_notification.id, news_notification: update_news_notification } 

      it 'should update news_notification' do
        expect{ 
          subject
          news_notification.reload
        }.to change{ news_notification.title }.to(update_news_notification[:title])
      end

      it 'should redirect_to news_notification' do
        subject
        expect( response ).to redirect_to(news_notification)
      end
    end

    context 'when update failed' do
      let(:update_news_notification) { { title: nil, body: nil } }
      let(:subject) { post :update, id: news_notification.id, news_notification: update_news_notification } 

      it 'should not update news_notification' do
        expect{ 
          subject
          news_notification.reload
        }.not_to change{ news_notification.title }.to(update_news_notification[:title])
      end

      it 'should redirect_to news_notification' do
        expect( subject ).to render_template(:edit)
      end
    end
  end

  describe 'destroy' do
    let!(:news_notification) { FactoryGirl.create(:news_notification) }
    let(:subject) { delete :destroy, id: news_notification.id }

    it 'should destroy news_notification' do
      expect{ subject }.to change( NewsNotification, :count ).by(-1)
    end

    it 'should redirect_to news_notifications_path' do
      expect( subject ).to redirect_to( news_notifications_path )
    end
  end
end
