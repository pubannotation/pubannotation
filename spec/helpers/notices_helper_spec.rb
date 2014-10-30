# encoding: utf-8
require 'spec_helper'

describe NoticesHelper do
  describe 'notices_list_helper' do
    before do
      @current_user = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, user: @current_user)
      @notice_1 = FactoryGirl.create(:notice, project: @project)
      @notices = [@notice_1]
      helper.stub(:current_user).and_return(@current_user)
    end

    context 'when @project.destroyable_for?' do
      before do
        @project.stub(:notices_destroyable_for?).and_return(true)
      end

      it 'should render template' do
        helper.should_receive(:render).with({partial: 'notices/notice', collection: @notices})
        helper.notices_list_helper
      end
    end

    context 'when @project.destroyable_for?' do
      before do
        @project.stub(:notices_destroyable_for?).and_return(false)
      end

      it 'should not render template' do
        helper.should_not_receive(:render).with({partial: 'notices/notice', collection: @notices})
        helper.notices_list_helper
      end
    end
  end
end
