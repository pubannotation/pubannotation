Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.max_attempts = 1
Delayed::Worker.destroy_failed_jobs = false
