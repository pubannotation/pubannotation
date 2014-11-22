require 'spec_helper'

describe Notice do
  describe 'belongs_to project' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
      @notice = FactoryGirl.create(:notice, project: @project)
    end

    it 'shoud belongs_to project' do
      @notice.project.should eql(@project)
    end
  end

  describe 'result' do
    before do
      @project = FactoryGirl.create(:project, user: FactoryGirl.create(:user))
    end

    context 'when successful == true' do
      it 'should return successful' do
        expect(FactoryGirl.create(:notice, project: @project, successful: true).result).to eql('successful')
      end
    end

    context 'when successful == false' do
      it 'should return unsuccessful' do
        expect(FactoryGirl.create(:notice, project: @project, successful: false).result).to eql('unsuccessful')
      end
    end
  end
end
