require 'spec_helper'

describe Instance do
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @instance = FactoryGirl.create(:instance,
        :hid => 'hid',
        :instype => 'instype',
        :insobj => @span,
        :project => @project
      )
      @get_hash = @instance.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@instance[:hid])
    end
    
    it 'should set instype as type' do
      @get_hash[:type].should eql(@instance[:instype])
    end
    
    it 'should set hid as object' do
      @get_hash[:object].should eql(@span[:hid])
    end
  end
end