require 'spec_helper'

describe Insann do
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @span = FactoryGirl.create(:span, :project => @project, :doc => @doc)
      @insann = FactoryGirl.create(:insann,
        :hid => 'hid',
        :instype => 'instype',
        :insobj => @span,
        :project => @project
      )
      @get_hash = @insann.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@insann[:hid])
    end
    
    it 'should set instype as type' do
      @get_hash[:type].should eql(@insann[:instype])
    end
    
    it 'should set hid as object' do
      @get_hash[:object].should eql(@span[:hid])
    end
  end
end