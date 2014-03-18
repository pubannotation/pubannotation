# encoding: utf-8
require 'spec_helper'

describe DocSequencerPubMed do
  describe 'self.generate' do
    context 'when response code is 200' do
      before do
        @id = '2626671'
        VCR.use_cassette 'lib/doc_sequencer_pubmed/initialize/response_code_200' do
          @pubmed = DocSequencerPubMed.new(@id)
        end
      end
      
      it 'should return new Doc' do
        @pubmed.instance_variable_get("@source_url").should eql "http://www.ncbi.nlm.nih.gov/pubmed/#{@id}"
      end
    end

    context 'when id is invalid' do
      it 'should railse error' do
        lambda{
          DocSequencerPubMed.new('0')
        }.should raise_error
      end
    end
  end  
end