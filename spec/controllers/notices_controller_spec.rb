# encoding: utf-8
require 'spec_helper'

describe NoticesController do
  describe 'destroy' do
    before  do
      controller.class.skip_before_filter :authenticate_user!
      @current_user = FactoryGirl.create(:user)
      current_user_stub(@current_user)
      @project = FactoryGirl.create(:project, user: @current_user)
      @notice = FactoryGirl.create(:notice, project: @project)
    end

    context 'when notice prensent? == true' do
      context 'when destroyable_for? == true' do
        before do
          @project.stub(:notices_destroyable_for?).and_return(true)
        end

        context 'when successfully deleted' do
          before do
            delete :destroy, id: @notice.id
          end

          it 'shoud render js hide notice div' do
            response.body.should eql("$('#notice_#{@notice.id}').hide();")
          end
        end

        context 'when unsuccessfully deleted' do
          before do
            Notice.any_instance.stub(:delete).and_return(nil)
            delete :destroy, id: @notice.id
          end

          it 'shoud render error message' do
            response.body.should eql("$('#notice_#{@notice.id}').text('#{I18n.t('errors.messages.failed_to_destroy')}');")
          end
        end
      end

      context 'when destroyable_for? == false' do
        before do
          Project.any_instance.stub(:notices_destroyable_for?).and_return(false)
          delete :destroy, id: @notice.id
        end

        it 'shoud render error message' do
          response.body.should eql("$('#notice_#{@notice.id}').text('#{I18n.t('errors.messages.failed_to_destroy')}');")
        end
      end
    end

    context 'when notice prensent? == false' do
      before do
        @id = 0
        delete :destroy, id: @id
      end

      it 'shoud render error message' do
        response.body.should eql("$('#notice_#{@id}').text('#{I18n.t('errors.messages.failed_to_destroy')}');")
      end
    end
  end
end
