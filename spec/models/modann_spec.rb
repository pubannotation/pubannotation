require 'spec_helper'

describe Relann do
  describe 'get_hash' do
    before do
      @annset = FactoryGirl.create(:annset, :user => FactoryGirl.create(:user))
      @doc = FactoryGirl.create(:doc, :sourcedb => 'sourcedb', :sourceid => 1, :serial => 1, :section => 'section', :body => 'doc body')
      @catann = FactoryGirl.create(:catann, :annset => @annset, :doc => @doc)
      @insann = FactoryGirl.create(:insann, :hid => 'insann hid', :annset => @annset, :insobj => @catann)
      @subcatrel = FactoryGirl.create(:subcatrel, :relobj => @catann, :annset => @annset)
      @insmod = FactoryGirl.create(:modann, 
        :hid => 'modann hid',
        :modtype => 'modtype',
        :modobj => @insann, 
        :annset => @annset
      )
      @get_hash = @insmod.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@insmod[:hid])
    end
    
    it 'should set modtype as type' do
      @get_hash[:type].should eql(@insmod[:modtype])
    end
    
    it 'should set end as span:end' do
      @get_hash[:object].should eql(@insann[:hid])
    end
  end
end