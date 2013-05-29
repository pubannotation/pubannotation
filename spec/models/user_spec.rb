require 'spec_helper'

describe User do
  describe 'self.find_first_by_auth_conditions' do
    before do
      @user_name = 'user_name'
      @user= FactoryGirl.create(:user, :id => 1, :username => @user_name)
    end

    context 'when conditions include login' do
      it 'should return user who matches login username' do
        User.find_first_by_auth_conditions({:login => @user_name}).should eql(@user)
      end
    end

    context 'when conditions does not include user name' do
      it '' do
        User.find_first_by_auth_conditions({:id => 1}).should eql(@user)
      end
    end
  end
end