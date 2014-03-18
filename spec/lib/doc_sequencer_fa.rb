# encoding: utf-8
require 'spec_helper'

describe DocSequencerFA do
  describe 'initialize' do
    context 'when response code is 200' do
      before do
        @id = '8424'
        @divs = 'divs'
        DocSequencerFA.any_instance.stub(:get_divs).and_return(@divs)
        VCR.use_cassette 'lib/doc_sequencer_fa/initialize' do
          @doc_sequencer = DocSequencerFA.new(@id)
        end
      end
      
      it 'should set @doc Nokogiri::HTML::Document' do
        @doc_sequencer.instance_variable_get("@doc").class.should eql Nokogiri::HTML::Document
      end
      
      it 'should set @source_url' do
        @doc_sequencer.instance_variable_get("@source_url").should eql "http://first.lifesciencedb.jp/archives/#{@id}"
      end
      
      it 'should set @divs' do
        @doc_sequencer.instance_variable_get("@divs").should eql @divs
      end
    end

    context 'when id is invalid' do
      it 'should railse error' do
        lambda{
          DocSequencerFA.new('0')
        }.should raise_error
      end
    end
  end  
  
  describe 'get_divs' do
    before do
      DocSequencerFA.any_instance.stub(:initialize).and_return(nil)
    end
    
    context 'when title and secs present' do
      before do
        @get_title = 'get_title'
        DocSequencerFA.any_instance.stub(:get_title).and_return(@get_title)
        @sec_1 = {:heading => 'heading_1', :body => 'body_1'}
        @sec_2 = {:heading => 'heading_2', :body => 'body_2'}
        @get_secs = [@sec_1, @sec_2]
        DocSequencerFA.any_instance.stub(:get_secs).and_return(@get_secs)
        @doc_sequencer = DocSequencerFA.new(nil)
        @divs = @doc_sequencer.get_divs
      end
      
      it 'should return divs' do
        @divs.should =~ [{:heading => 'TIAB', :body => "#{@get_title}\n#{@sec_1[:body]}"}] + @get_secs
      end
    end
    
    context 'when title and secs nil' do
      before do
        @get_title = 'get_title'
        DocSequencerFA.any_instance.stub(:get_title).and_return(nil)
        DocSequencerFA.any_instance.stub(:get_secs).and_return(nil)
        @doc_sequencer = DocSequencerFA.new(nil)
        @divs = @doc_sequencer.get_divs
      end
      
      it 'should return divs' do
        @divs.should be_nil
      end
    end
  end
end