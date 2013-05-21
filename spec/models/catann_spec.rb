require 'spec_helper'

describe Catann do
  describe 'get_hash' do
    before do
      @catann = FactoryGirl.create(:catann,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :category => 'category',
        :project_id => 'project_id',
        :doc_id => 3
      )
      @get_hash = @catann.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@catann[:hid])
    end
    
    it 'should set begin as span:begin' do
      @get_hash[:span][:begin].should eql(@catann[:begin])
    end
    
    it 'should set end as span:end' do
      @get_hash[:span][:end].should eql(@catann[:end])
    end
    
    it 'category as category' do
      @get_hash[:category].should eql(@catann[:category])
    end
  end
end