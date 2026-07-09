# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Job, type: :model do
  describe '#elapsed_time' do
    it 'returns nil when the job has not begun' do
      job = build(:job, begun_at: nil)
      expect(job.elapsed_time).to be_nil
    end

    it 'returns the time since begun_at when still running' do
      job = build(:job, begun_at: 10.seconds.ago, ended_at: nil)
      expect(job.elapsed_time(Time.current)).to be_within(0.1).of(10)
    end

    it 'returns the time between begun_at and ended_at when finished' do
      job = build(:job, begun_at: Time.current, ended_at: 10.seconds.from_now)
      expect(job.elapsed_time).to be_within(0.1).of(10)
    end
  end

  describe '#pace' do
    it 'returns nil when no items are done yet' do
      job = build(:job, begun_at: 10.seconds.ago, num_dones: 0)
      expect(job.pace).to be_nil
    end

    it 'returns nil when the job has not begun' do
      job = build(:job, begun_at: nil, num_dones: 5)
      expect(job.pace).to be_nil
    end

    it 'returns num_dones per second elapsed' do
      job = build(:job, begun_at: 10.seconds.ago, ended_at: nil, num_dones: 5)
      expect(job.pace(Time.current)).to be_within(0.05).of(0.5)
    end
  end

  describe '#estimated_remaining_time' do
    it 'returns nil when pace cannot be computed' do
      job = build(:job, begun_at: nil, num_items: 100, num_dones: 0)
      expect(job.estimated_remaining_time).to be_nil
    end

    it 'returns the remaining items divided by the current pace' do
      job = build(:job, begun_at: 10.seconds.ago, ended_at: nil, num_items: 100, num_dones: 5)
      expect(job.estimated_remaining_time(Time.current)).to be_within(1).of(190)
    end
  end
end
