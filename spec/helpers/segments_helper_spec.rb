# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SegmentsHelper, type: :helper do
  describe '#segment_time' do
    it 'formats a playback time in ms as m:ss.mmm' do
      expect(helper.segment_time(61_234)).to eq('1:01.234')
    end
  end

  describe '#segment_time_range' do
    it "formats a segment's start and end times" do
      expect(helper.segment_time_range({ 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 3000 })).to eq('0:00.000 - 0:03.000')
    end
  end
end
