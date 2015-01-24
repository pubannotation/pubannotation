# encoding: utf-8
require 'spec_helper'

describe DocSequencerPMC do
  describe 'self.generate' do
    context 'when response code is 200' do
      ids = IO.readlines("spec/fixtures/craft-pmcids.lst").map{|l| l.chomp}
      ids.each do |id|
        it "should return new Doc for #{id}" do
          pmcdoc = 
            VCR.use_cassette "lib/doc_sequencer_pmc/initialize/#{id}/response_code_200" do
              DocSequencerPMC.new(id)
            end
          pmcdoc.instance_variable_get("@source_url").should eql "http://www.ncbi.nlm.nih.gov/pmc/#{id}"
          expect(pmcdoc.instance_variable_get("@divs")).not_to be_nil
        end
      end
      
    end

    context 'when id is invalid' do
      it 'should railse error' do
        expect{DocSequencerPMC.new()}.to raise_error(ArgumentError)
        expect{DocSequencerPMC.new('')}.to raise_error(ArgumentError)
        expect{DocSequencerPMC.new(' ')}.to raise_error(ArgumentError)
        expect{DocSequencerPMC.new('0')}.to raise_error(ArgumentError)
        expect{DocSequencerPMC.new('XYZ12345')}.to raise_error(ArgumentError)
      end
    end
  end  
end