FactoryBot.define do
  factory :job do
    # Polymorphic association - use project as default organization
    association :organization, factory: :project

    name { "Test Job #{rand(1000..9999)}" }
    num_items { 100 }
    num_dones { 0 }
    begun_at { Time.current }
    active_job_id { "job_#{SecureRandom.hex(12)}" }
    queue_name { 'default' }
    suspend_flag { false }

    trait :completed do
      num_dones { num_items }
      ended_at { Time.current }
    end

    trait :in_progress do
      num_dones { num_items / 2 }
    end

    trait :suspended do
      suspend_flag { true }
    end
  end
end
