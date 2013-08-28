# encoding: utf-8
require 'spec_helper'

describe AssociateMaintainer do
  before do
    @associate_user = FactoryGirl.create(:user)
    @associate_project = FactoryGirl.create(:project)   
  end
  
  describe 'belongs_to' do
    describe 'user' do
      before do
        @associate_maintainer = FactoryGirl.create(:associate_maintainer, 
          :user => @associate_user,
          :project => @associate_project)
      end     
    end
  end
  
  describe 'validate' do
    context 'when user_id blank' do
      it 'should not valid' do
        associate_maintainer = AssociateMaintainer.new()
        associate_maintainer.project = @associate_project
        associate_maintainer.valid?.should be_false
      end
    end
    
    context 'when project_id blank' do
      it 'should not valid' do
        associate_maintainer = AssociateMaintainer.new({:user_id => @associate_user.id})
        associate_maintainer.valid?.should be_false
      end
    end
  end
  
  describe 'destroyable_for?' do
    before do
      @maintainer = FactoryGirl.create(:user)
      @project = FactoryGirl.create(:project, :user => @maintainer)
      @associate_maintainer = FactoryGirl.create(:associate_maintainer, 
        :user => @associate_user,
        :project => @project)
    end
    
    context 'when current_user is self.user' do
      it 'should return true' do
        @associate_maintainer.destroyable_for?(@associate_user).should be_true
      end
    end
    
    context 'when current_user is @project.user' do
      it 'should return true' do
        @associate_maintainer.destroyable_for?(@maintainer).should be_true
      end
    end
    
    context 'when current_user is not self.user nor project.user' do
      it 'should return false' do
        @associate_maintainer.destroyable_for?(FactoryGirl.create(:user)).should be_false
      end
    end
  end
end