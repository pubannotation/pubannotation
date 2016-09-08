require 'spec_helper'

describe VisitLog do
  describe 'scope top' do
    before do
      user = FactoryGirl.create(:user)
      @project_visits_2 = FactoryGirl.create(:project, user: user)
      2.times do
        FactoryGirl.create(:visit_log, project: @project_visits_2)
      end
      @project_visits_3 = FactoryGirl.create(:project, user: user)
      3.times do
        FactoryGirl.create(:visit_log, project: @project_visits_3)
      end
      @project_visits_0 = FactoryGirl.create(:project, user: user)
    end

    it 'should order by visit_logs count' do
      expect( VisitLog.top(3).first.project ).to eql(@project_visits_3)
      expect( VisitLog.top(3).second.project ).to eql(@project_visits_2)
    end
  end
end
