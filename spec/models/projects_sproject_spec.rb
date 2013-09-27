# encoding: utf-8
require 'spec_helper'

describe ProjectsSproject do
  describe 'decrement_counters' do
    before do
      @sproject = FactoryGirl.create(:sproject,
        :pmdocs_count => 10,
        :pmcdocs_count => 20,
        :denotations_count => 30,
        :relations_count => 40
      )
      @project = FactoryGirl.create(:project,
        :pmdocs_count => 1,
        :pmcdocs_count => 2,
        :denotations_count => 3,
        :relations_count => 4
      )
      @projects_sprojects = FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject.id)
      @projects_sprojects.decrement_counters
    end
    
    it 'should increment sproject.counters' do
      @sproject.reload
      @sproject.pmdocs_count.should eql(9)
      @sproject.pmcdocs_count.should eql(18)
      @sproject.denotations_count.should eql(27)
      @sproject.relations_count.should eql(36)
    end
  end
end