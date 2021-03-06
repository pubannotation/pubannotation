Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.max_attempts = 1
Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.max_run_time = 14.days
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))
Delayed::Worker.queue_attributes = {
  general: { priority: 0 },
  low_priority: { priority: 10 }
}
