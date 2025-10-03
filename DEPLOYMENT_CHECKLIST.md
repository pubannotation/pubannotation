# Batch Job Tracking - Deployment Checklist

## Pre-Deployment

- [ ] Review all code changes
  - [ ] `db/migrate/20251003130937_create_batch_job_tracking.rb`
  - [ ] `app/models/batch_job_tracking.rb`
  - [ ] `app/jobs/store_annotations_collection_upload_job.rb`
  - [ ] `app/jobs/process_annotations_batch_job.rb`

- [ ] Run tests
  ```bash
  bundle exec rspec spec/models/batch_job_tracking_spec.rb
  bundle exec rspec spec/jobs/store_annotations_collection_upload_job_tracking_spec.rb
  ```

- [ ] Test in development
  ```bash
  # Terminal 1: Start Sidekiq
  bundle exec sidekiq -C config/sidekiq.yml

  # Terminal 2: Rails console
  rails console
  project = Project.first
  StoreAnnotationsCollectionUploadJob.perform_later(project, 'test.jsonl', {mode: 'replace'})

  # Terminal 3: Watch logs
  tail -f log/sidekiq.log | grep "BatchJobTracking\|Progress"
  ```

- [ ] Verify tracking records created
  ```bash
  rails console
  BatchJobTracking.last(5).each { |t| puts "#{t.status}: #{t.doc_summary}" }
  ```

## Deployment Steps

### 1. Database Migration

- [ ] Review migration
  ```bash
  rails db:migrate:status
  ```

- [ ] Run migration in production
  ```bash
  # Heroku
  heroku run rails db:migrate -a your-app

  # Or Capistrano
  cap production deploy:migrate

  # Or manual
  RAILS_ENV=production bundle exec rails db:migrate
  ```

- [ ] Verify migration succeeded
  ```bash
  heroku run rails console -a your-app
  # In console:
  ActiveRecord::Base.connection.table_exists?('batch_job_trackings')
  # => true

  BatchJobTracking.create!(
    parent_job_id: Job.last.id,
    doc_identifiers: [{sourcedb: 'test', sourceid: '123'}],
    item_count: 1
  )
  # Should succeed
  ```

### 2. Code Deployment

- [ ] Commit changes
  ```bash
  git add .
  git commit -m "Add batch job tracking system for crash detection"
  ```

- [ ] Push to production
  ```bash
  git push production main
  # or
  cap production deploy
  ```

- [ ] Restart workers
  ```bash
  # Heroku
  heroku restart -a your-app

  # Or systemd
  sudo systemctl restart sidekiq
  ```

### 3. Verification

- [ ] Check Sidekiq is running
  ```bash
  # Via Sidekiq web UI
  open https://your-app.com/sidekiq

  # Or console
  heroku run rails console -a your-app
  Sidekiq::ProcessSet.new.size
  # => should be > 0
  ```

- [ ] Test with small upload
  - Upload a small annotation file (<10 docs) via UI
  - Monitor progress in UI
  - Check tracking in console:
    ```bash
    rails console
    job = Job.last
    BatchJobTracking.where(parent_job_id: job.id).group(:status).count
    # => {"completed"=>2, "pending"=>0, "running"=>0}
    ```

- [ ] Test with larger upload
  - Upload larger file (100+ docs)
  - Verify crash detection works (if any crashes occur)
  - Check logs for progress updates

### 4. Monitoring Setup

- [ ] Set up log monitoring
  ```bash
  # Watch for crashes
  tail -f log/production.log | grep -i "crashed\|CRASHED"

  # Or use log aggregator (Papertrail, Datadog, etc.)
  # Add alert for: "Detected * potentially crashed jobs"
  ```

- [ ] Create monitoring dashboard (optional)
  ```ruby
  # Add to admin panel or create rake task
  namespace :batch_tracking do
    desc "Show batch job health stats"
    task health: :environment do
      puts "\nBatch Job Tracking Health (Last 24h)\n"
      puts "=" * 60

      last_day = 24.hours.ago

      stats = {
        total: BatchJobTracking.where('created_at > ?', last_day).count,
        completed: BatchJobTracking.completed.where('created_at > ?', last_day).count,
        failed: BatchJobTracking.failed.where('created_at > ?', last_day).count,
        crashed: BatchJobTracking.crashed.where('created_at > ?', last_day).count
      }

      puts "Total batches: #{stats[:total]}"
      puts "Completed: #{stats[:completed]} (#{(stats[:completed].to_f/stats[:total]*100).round(1)}%)"
      puts "Failed: #{stats[:failed]}"
      puts "Crashed: #{stats[:crashed]}"

      if stats[:crashed] > 0
        puts "\nRecent crashes:"
        BatchJobTracking.crashed.where('created_at > ?', last_day).limit(5).each do |t|
          puts "  - Job #{t.parent_job_id}: #{t.doc_summary}"
        end
      end
    end
  end
  ```

### 5. Cleanup Setup (Optional)

- [ ] Set up scheduled cleanup job
  ```ruby
  # config/schedule.rb (if using whenever gem)
  every 1.day, at: '3:00 am' do
    rake "batch_tracking:cleanup"
  end

  # lib/tasks/batch_tracking.rake
  namespace :batch_tracking do
    desc "Clean up old batch tracking records"
    task cleanup: :environment do
      deleted = BatchJobTracking.older_than(7.days.ago).delete_all
      puts "Deleted #{deleted} old batch tracking records"
    end
  end
  ```

- [ ] Or use Heroku Scheduler
  ```
  Task: rake batch_tracking:cleanup
  Dyno size: Standard-1X
  Frequency: Daily at 3:00 AM
  ```

## Post-Deployment

### First 24 Hours

- [ ] Monitor first few uploads
  - Check logs every 2-3 hours
  - Look for any crashes
  - Verify progress updates correctly

- [ ] Check tracking table size
  ```sql
  SELECT COUNT(*) FROM batch_job_trackings;
  SELECT pg_size_pretty(pg_total_relation_size('batch_job_trackings'));
  ```

- [ ] Review any crashes
  ```bash
  rails console
  BatchJobTracking.crashed.each do |t|
    puts "Crashed: #{t.doc_summary}"
    puts "Error: #{t.error_message}"
    puts "---"
  end
  ```

### First Week

- [ ] Analyze crash patterns
  ```sql
  -- Crash rate by day
  SELECT
    DATE(created_at) as date,
    COUNT(*) FILTER (WHERE status = 'crashed') as crashed,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'crashed') / COUNT(*), 2) as crash_rate_pct
  FROM batch_job_trackings
  WHERE created_at > NOW() - INTERVAL '7 days'
  GROUP BY DATE(created_at)
  ORDER BY date DESC;
  ```

- [ ] Performance check
  ```sql
  -- Average batch processing time
  SELECT
    AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_seconds,
    MAX(EXTRACT(EPOCH FROM (completed_at - started_at))) as max_seconds,
    COUNT(*) as count
  FROM batch_job_trackings
  WHERE status = 'completed'
  AND created_at > NOW() - INTERVAL '7 days';
  ```

- [ ] Cleanup verification
  ```bash
  # If you set up cleanup, verify it's running
  rails console
  # Should only have recent records (< 7 days old)
  BatchJobTracking.minimum(:created_at)
  # => should be within last 7 days
  ```

## Rollback Plan

If issues occur:

### Rollback Code

```bash
# Revert to previous version
git revert HEAD
git push production main

# Or rollback release
heroku releases:rollback -a your-app
```

### Rollback Database (if needed)

```bash
# Create rollback migration
rails g migration RemoveBatchJobTracking

# In migration:
def up
  drop_table :batch_job_trackings
end

def down
  # Copy schema from create_batch_job_tracking.rb
end

# Deploy
rails db:migrate
```

### Switch Back to Old Progress Tracking

1. Restore old `store_annotations_collection_upload_job.rb` from git
2. Restore old `process_annotations_batch_job.rb` from git
3. Deploy

## Troubleshooting

### Issue: Migration fails

**Error:** `PG::UndefinedTable: ERROR: relation "jobs" does not exist`

**Solution:** Ensure `jobs` table exists first

```bash
rails console
ActiveRecord::Base.connection.tables
# Should include 'jobs'
```

### Issue: No tracking records created

**Symptom:** Job runs but no records in `batch_job_trackings`

**Check:**
1. Is Sidekiq running? `Sidekiq::ProcessSet.new.size`
2. Are jobs being processed? Check Sidekiq web UI
3. Check logs for errors: `tail -f log/sidekiq.log`

**Solution:** Ensure job is actually running, not queued

### Issue: All jobs marked as crashed

**Symptom:** All tracking records show status='crashed'

**Check:** `CRASH_DETECTION_TIMEOUT` setting (default 10 minutes)

**Solution:** If jobs are slow, increase timeout:
```ruby
# In StoreAnnotationsCollectionUploadJob
CRASH_DETECTION_TIMEOUT = 30.minutes
```

### Issue: Tracking table growing too large

**Symptom:** `batch_job_trackings` table > 1GB

**Check:** Current size
```sql
SELECT pg_size_pretty(pg_total_relation_size('batch_job_trackings'));
SELECT COUNT(*) FROM batch_job_trackings;
```

**Solution:** Set up cleanup job (see "Cleanup Setup" above)

## Success Criteria

- [ ] All tests passing
- [ ] Migration completed successfully
- [ ] Code deployed without errors
- [ ] Sidekiq workers running
- [ ] At least one successful upload with tracking
- [ ] Progress updates correctly in UI
- [ ] No unexpected errors in logs
- [ ] Crash detection working (if crashes occur)
- [ ] Cleanup job scheduled (optional)

## Contact

If issues arise:
- Check documentation: `docs/BATCH_JOB_TRACKING.md`
- Review implementation: `BATCH_TRACKING_IMPLEMENTATION.md`
- Check logs: `tail -f log/production.log log/sidekiq.log`

---

**Deployment Date:** _______________
**Deployed By:** _______________
**Notes:** _______________________________________________
