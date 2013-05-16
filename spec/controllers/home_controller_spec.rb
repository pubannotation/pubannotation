# encoding: utf-8
require 'spec_helper'

describe HomeController do
  describe 'index' do
    before do
      @serial_0_length = 2
      @serial_0_length.times do
        FactoryGirl.create(:doc, :serial => 0)
      end
      @pmdocs_num = 3
      @pmdocs_num.times do
        FactoryGirl.create(:doc, :sourcedb => 'PubMed', :serial => 0)
      end
      @pmcdocs_num = 4
      @pmcdocs_num.times do
        FactoryGirl.create(:doc, :sourcedb => 'PMC', :serial => 0)
      end
      @get_annsets = [1, 2, 3]
      controller.stub(:get_annsets).and_return(@get_annsets)
      get :index
    end
    
    it '@dosc_num should eql Doc.where serial == 0 count' do
      assigns[:docs_num].should eql(@serial_0_length + @pmdocs_num + @pmcdocs_num)
    end
    
    it '@pmdocs_num should eql Doc.where sourcedb == PubMed count' do
      assigns[:pmdocs_num].should eql(@pmdocs_num)
    end
    
    it '@annsets_num should eql get_annsets.length' do
      assigns[:annsets_num].should eql(@get_annsets.length)
    end
  end
end