# encoding: utf-8
require 'spec_helper'

describe Div do
  describe 'body' do
    let(:doc) { FactoryGirl.create(:doc, body: 'This doc has body more then 10 characters.') }
    let(:begin_pos) { 5 }
    let(:end_pos) { 10 }
    let(:div) { FactoryGirl.create(:div, begin: begin_pos, end: end_pos, doc: doc) }

    it 'should return range of doc doby' do
      expect( div.body ).to eql( doc.body[begin_pos...end_pos] )
    end
  end
end
