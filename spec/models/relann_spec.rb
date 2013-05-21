require 'spec_helper'

describe Relann do
  describe 'get_hash' do
    before do
      @project = FactoryGirl.create(:project, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @catann_sub = FactoryGirl.create(:catann, :id => 1, :hid => 'catann sub hid', :project => @project, :doc => @doc)
      @catann_relobj = FactoryGirl.create(:catann, :id => 2, :hid => 'catann rel hid', :project => @project, :doc => @doc)
      @relann = FactoryGirl.create(:relann, 
      :hid => 'hid',
      :reltype => 'lexChain', 
      :relobj => @catann_relobj, 
      :project => @project)
      @get_hash = @relann.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@relann[:hid])
    end
    
    it 'should set reltype as type' do
      @get_hash[:type].should eql(@relann[:reltype])
    end
    
    it 'should set end as span:end' do
      @get_hash[:subject].should eql(@catann_sub[:hid])
    end
    
    it 'should set end as span:end' do
      @get_hash[:object].should eql(@catann_relobj[:hid])
    end
  end
end