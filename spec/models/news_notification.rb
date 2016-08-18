# encoding: utf-8
require 'spec_helper'

describe NewsNotification do
  describe 'validation' do
    context 'when title, body present' do
      let(:news_notification) { NewsNotification.new(title: 'Title', body: 'Body')}

      it 'shold be valid' do
        expect( news_notification.valid? ).to be_true
      end
    end

    context 'when title is nil' do
      let(:news_notification) { NewsNotification.new(title: nil, body: 'Body')}

      it 'shold be invalid' do
        expect( news_notification.valid? ).to be_false
      end
    end

    context 'when body is nil' do
      let(:news_notification) { NewsNotification.new(title: 'Title', body: nil)}

      it 'shold be invalid' do
        expect( news_notification.valid? ).to be_false
      end
    end
  end

  describe 'default_scope' do
    let!(:news_notification_1) { FactoryGirl.create(:news_notification, updated_at: 1.minutes.ago) }
    let!(:news_notification_2) { FactoryGirl.create(:news_notification, updated_at: 1.hour.ago) }
    let!(:news_notification_3) { FactoryGirl.create(:news_notification, updated_at: 3.days.ago) }

    it 'shoould order by updated_at' do
      expect( NewsNotification.first ).to eql(news_notification_1)
      expect( NewsNotification.last ).to eql(news_notification_3)
    end
  end
end
