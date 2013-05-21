require 'spec_helper'

describe Span do
  describe 'get_hash' do
    before do
      @span = FactoryGirl.create(:span,
        :hid => 'hid',
        :begin => 1,
        :end => 5,
        :category => 'category',
        :project_id => 'project_id',
        :doc_id => 3
      )
      @get_hash = @span.get_hash
    end
    
    it 'should set hid as id' do
      @get_hash[:id].should eql(@span[:hid])
    end
    
    it 'should set begin as span:begin' do
      @get_hash[:span][:begin].should eql(@span[:begin])
    end
    
    it 'should set end as span:end' do
      @get_hash[:span][:end].should eql(@span[:end])
    end
    
    it 'category as category' do
      @get_hash[:category].should eql(@span[:category])
    end
  end
end