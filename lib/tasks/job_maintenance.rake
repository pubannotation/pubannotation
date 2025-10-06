namespace :jobs do
  desc "Detect and cleanup crashed parent jobs"
  task detect_crashed: :environment do
    crashed_count = Job.detect_and_cleanup_crashed_jobs
    if crashed_count > 0
      puts "Detected and cleaned up #{crashed_count} crashed job(s)"
    else
      puts "No crashed jobs detected"
    end
  end
end
