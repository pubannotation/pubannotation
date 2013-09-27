# encoding: utf-8
require 'spec_helper'

describe ProjectsSprojectsController do
  describe 'destroy' do
    before do
      request.env["HTTP_REFERER"] = sprojects_path
      @project = FactoryGirl.create(:project, :pmdocs_count => 1, :pmcdocs_count => 2, :denotations_count => 3, :relations_count => 4)
      @sproject = FactoryGirl.create(:sproject, :pmdocs_count => 10, :pmcdocs_count => 20, :denotations_count => 30, :relations_count => 40)
      @projects_sproject = FactoryGirl.create(:projects_sproject, :project_id => @project.id, :sproject_id => @sproject.id)
      delete :destroy, :id => @projects_sproject.id
    end
    
    it 'should delete record' do
      ProjectsSproject.where(:id => @projects_sproject).should be_blank
    end
    
    it 'should redirect referer path' do
      response.should redirect_to(sprojects_path) 
    end
    
    it 'should decrement sproject.counters' do
      @sproject.reload
      @sproject.pmdocs_count.should eql(9)
      @sproject.pmcdocs_count.should eql(18)
      @sproject.denotations_count.should eql(27)
      @sproject.relations_count.should eql(36)
    end
  end
end