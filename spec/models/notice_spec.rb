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
end
