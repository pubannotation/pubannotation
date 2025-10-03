FactoryBot.define do
  factory :batch_job_tracking do
    association :parent_job, factory: :job
    child_job_id { "sidekiq_job_#{SecureRandom.hex(12)}" }
    status { 'pending' }
    doc_identifiers do
      [
        { 'sourcedb' => 'PMC', 'sourceid' => rand(100000..999999).to_s }
      ]
    end
    item_count { rand(1..100) }
    error_message { nil }
    started_at { nil }
    completed_at { nil }

    trait :pending do
      status { 'pending' }
    end

    trait :running do
      status { 'running' }
      started_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      started_at { 2.minutes.ago }
      completed_at { Time.current }
      error_message { 'RuntimeError: Something went wrong' }
    end

    trait :crashed do
      status { 'crashed' }
      started_at { 10.minutes.ago }
      completed_at { Time.current }
      error_message { 'Job did not update status within expected timeframe (likely crashed or killed)' }
    end

    trait :stale do
      status { 'running' }
      started_at { 15.minutes.ago }
      updated_at { 15.minutes.ago }
    end
  end
end
