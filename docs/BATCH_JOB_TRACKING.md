# Batch Job Tracking System

## Overview

The batch job tracking system provides robust monitoring and crash detection for the parent-child job architecture used in annotation uploads. Instead of child jobs voluntarily reporting progress, the parent job now actively tracks all child jobs and detects failures/crashes.

## Architecture

### Before (Voluntary Reporting)
```
Parent Job
  ├─ spawn Child Job 1 ──> voluntarily calls increment_progress(n)
  ├─ spawn Child Job 2 ──> voluntarily calls increment_progress(n)
  └─ poll job.num_dones until complete
     Problem: If child crashes (segfault), progress never updates!
```

### After (Active Tracking)
```
Parent Job
  ├─ create BatchJobTracking(status: 'pending')
  ├─ spawn Child Job 1 with tracking_id
  │    └─ Child updates tracking: pending → running → completed
  ├─ poll BatchJobTracking table
  ├─ detect crashed jobs (running too long)
  └─ update job.num_dones based on tracking table
```

## Database Schema

```ruby
create_table :batch_job_trackings do |t|
  t.bigint :parent_job_id, null: false
  t.string :child_job_id              # Sidekiq job ID
  t.string :status                     # pending, running, completed, failed, crashed
  t.json :doc_identifiers              # Which docs this batch processes
  t.integer :item_count                # Number of annotations in batch
  t.text :error_message                # Error details if failed
  t.datetime :started_at
  t.datetime :completed_at
  t.timestamps
end
```

## Job Lifecycle

### 1. Parent Job Creates Tracking Record

```ruby
# In StoreAnnotationsCollectionUploadJob::BatchState#flush_batch
tracking = BatchJobTracking.create!(
  parent_job_id: @job_id,
  doc_identifiers: extract_doc_identifiers(@annotations),
  item_count: @current_batch_size,
  status: 'pending'
)
```

### 2. Parent Enqueues Child Job

```ruby
child_job = ProcessAnnotationsBatchJob.perform_later(
  @project,
  @annotations,
  @options,
  @job_id,
  tracking.id  # Pass tracking ID
)

tracking.update!(child_job_id: child_job.job_id)
```

### 3. Child Job Updates Tracking

```ruby
# In ProcessAnnotationsBatchJob#perform
def perform(project, annotations, options, parent_job_id, tracking_id)
  @tracking = BatchJobTracking.find(tracking_id)
  @tracking.mark_running!  # pending → running

  # Process annotations...

  @tracking.mark_completed!  # running → completed
rescue => e
  @tracking.mark_failed!(e)  # running → failed
  raise
end
```

### 4. Parent Monitors Progress

```ruby
# In StoreAnnotationsCollectionUploadJob#wait_for_batch_jobs_completion
loop do
  # Single efficient query with aggregation
  stats = BatchJobTracking.stats_for_parent(@job.id)
  # => { 'pending' => 100, 'running' => 50, 'completed' => 200, 'failed' => 5 }

  completed = stats['completed'] + stats['failed'] + stats['crashed']
  total = stats.values.sum

  # Parent controls progress counter
  @job.update!(num_dones: completed, num_items: total)

  break if completed >= total
  sleep(0.5)
end
```

### 5. Crash Detection

```ruby
# Every 2 minutes, detect stale jobs
def detect_and_mark_crashed_jobs
  BatchJobTracking
    .for_parent(@job.id)
    .possibly_crashed(10.minutes)  # Running but not updated in 10 min
    .find_each do |tracking|
      tracking.mark_crashed!
      log_crashed_batch(tracking)
    end
end
```

## Key Benefits

### 1. **Crash Detection**
- **Problem:** Child job segfaults → progress counter never updates → parent waits forever
- **Solution:** Parent detects jobs stuck in 'running' status for >10 minutes → marks as 'crashed'

```ruby
# Example: Segfault scenario
Parent: Created tracking #123 (status: pending)
Parent: Enqueued child job abc-123
Child:  Updated tracking #123 → running
Child:  [SEGFAULT - process killed]
Parent: [2 min later] Checking... tracking #123 still 'running'
Parent: [10 min later] Detected crash! Updated tracking #123 → crashed
Parent: Progress: 950/1000 completed (50 crashed)
```

### 2. **Debugging Failed Batches**

```sql
-- Find which documents caused failures
SELECT doc_identifiers, error_message
FROM batch_job_trackings
WHERE parent_job_id = 123 AND status = 'failed'
ORDER BY created_at;

-- Find slowest batches
SELECT
  id,
  item_count,
  (completed_at - started_at) AS duration,
  status
FROM batch_job_trackings
WHERE parent_job_id = 123
ORDER BY duration DESC
LIMIT 10;
```

### 3. **Accurate Progress**
- Parent fully controls `job.num_dones` based on tracking table
- No race conditions from concurrent child updates
- Failed/crashed batches counted correctly

### 4. **Historical Analysis**

```ruby
# Which docs fail most often?
SELECT
  doc_identifiers->>'sourceid' AS doc_id,
  COUNT(*) as failure_count
FROM batch_job_trackings
WHERE status = 'failed'
GROUP BY doc_identifiers->>'sourceid'
ORDER BY failure_count DESC;

# Average batch processing time by status
SELECT
  status,
  AVG(completed_at - started_at) as avg_duration,
  COUNT(*) as count
FROM batch_job_trackings
WHERE parent_job_id = 123
GROUP BY status;
```

## Model API

### Scopes

```ruby
BatchJobTracking.for_parent(job_id)         # All trackings for parent job
BatchJobTracking.pending                     # Status = 'pending'
BatchJobTracking.running                     # Status = 'running'
BatchJobTracking.completed                   # Status = 'completed'
BatchJobTracking.failed                      # Status = 'failed'
BatchJobTracking.crashed                     # Status = 'crashed'
BatchJobTracking.finished                    # completed | failed | crashed
BatchJobTracking.possibly_crashed(timeout)   # Running but stale
BatchJobTracking.older_than(time)            # For cleanup
```

### Instance Methods

```ruby
tracking.mark_running!       # pending → running, set started_at
tracking.mark_completed!     # running → completed, set completed_at
tracking.mark_failed!(error) # running → failed, set error_message
tracking.mark_crashed!       # running → crashed

tracking.duration            # completed_at - started_at
tracking.status_label        # Human-readable status
tracking.doc_summary(limit)  # "PMC:123, PMC:456... (10 more)"
```

### Class Methods

```ruby
# Get aggregated stats
stats = BatchJobTracking.stats_for_parent(job_id)
# => { 'pending' => 100, 'running' => 50, 'completed' => 200 }

completed = stats['completed'] + stats['failed'] + stats['crashed']
total = stats.values.sum
progress_percent = (completed.to_f / total * 100).round(1)
```

## Maintenance

### Cleanup Old Records

```ruby
# In a scheduled job (e.g., daily)
class CleanupOldBatchTrackingJob < ApplicationJob
  def perform
    # Delete tracking records older than 7 days
    deleted = BatchJobTracking.older_than(7.days.ago).delete_all
    Rails.logger.info "Cleaned up #{deleted} old batch tracking records"
  end
end
```

### Or Keep for Historical Analysis

```ruby
# In StoreAnnotationsCollectionUploadJob#cleanup_tracking_records
def cleanup_tracking_records
  # Option 1: Delete immediately (default)
  BatchJobTracking.for_parent(@job.id).delete_all

  # Option 2: Archive to separate table
  # BatchJobTracking.for_parent(@job.id).each do |tracking|
  #   BatchJobTrackingArchive.create!(tracking.attributes)
  # end
  # BatchJobTracking.for_parent(@job.id).delete_all

  # Option 3: Keep indefinitely (comment out cleanup)
  # (useful for debugging and analytics)
end
```

## Monitoring & Alerts

### Check for Crashes

```ruby
# Count crashed jobs in last 24 hours
crashed_count = BatchJobTracking
  .where(status: 'crashed')
  .where('created_at > ?', 24.hours.ago)
  .count

# Alert if > threshold
if crashed_count > 10
  AlertService.notify("High crash rate: #{crashed_count} batches crashed in 24h")
end
```

### Performance Monitoring

```ruby
# Average batch processing time
avg_duration = BatchJobTracking
  .where(status: 'completed')
  .where('completed_at > ?', 24.hours.ago)
  .average('EXTRACT(EPOCH FROM (completed_at - started_at))')

puts "Average batch time: #{avg_duration.round(2)} seconds"
```

## Configuration

```ruby
# In StoreAnnotationsCollectionUploadJob
MAX_BATCH_SIZE = 500                  # Items per batch
MAX_CONCURRENT_JOBS = 20              # Max child jobs running at once
CRASH_DETECTION_TIMEOUT = 10.minutes  # Mark as crashed after this timeout
```

## Troubleshooting

### Issue: Jobs stuck in 'running' forever

**Diagnosis:**
```sql
SELECT * FROM batch_job_trackings
WHERE status = 'running'
AND updated_at < NOW() - INTERVAL '10 minutes';
```

**Solution:** The crash detection will automatically mark these as 'crashed' after 10 minutes.

### Issue: Too many tracking records in database

**Diagnosis:**
```sql
SELECT COUNT(*) FROM batch_job_trackings;
SELECT COUNT(*) FROM batch_job_trackings WHERE created_at < NOW() - INTERVAL '7 days';
```

**Solution:** Run cleanup job or reduce retention period.

### Issue: Need to know which exact annotation caused crash

**Diagnosis:**
```sql
SELECT
  bt.doc_identifiers,
  bt.error_message,
  bt.started_at,
  bt.completed_at
FROM batch_job_trackings bt
WHERE bt.parent_job_id = 123
AND bt.status = 'crashed'
ORDER BY bt.created_at;
```

**Solution:** The `doc_identifiers` field shows which documents were in the crashed batch. Inspect the JSONL file for those specific documents.

## Migration Guide

### Step 1: Run Migration

```bash
rails db:migrate
```

### Step 2: Deploy Code

Deploy the updated `StoreAnnotationsCollectionUploadJob` and `ProcessAnnotationsBatchJob`.

### Step 3: Monitor

Check logs for tracking creation and crash detection:

```bash
tail -f log/sidekiq.log | grep "BatchJobTracking\|Tracking\|crashed"
```

### Step 4: Verify

After first upload completes, check tracking table:

```sql
SELECT
  status,
  COUNT(*) as count,
  SUM(item_count) as total_items
FROM batch_job_trackings
WHERE parent_job_id = <your_job_id>
GROUP BY status;
```

Should see all batches in 'completed' status (or 'failed'/'crashed' with explanations).

## Performance Impact

### Database Overhead

- **3 writes per batch:** create, update job_id, update status
- **1 query per 0.5s:** aggregated stats query (very fast with indexes)
- **Typical overhead:** ~5-10ms per batch (negligible)

### Storage

- ~500 bytes per tracking record
- 1,000 batches = ~500 KB
- Cleanup recommended after 7 days

### Query Performance

With proper indexes, stats query remains fast even with 10,000+ tracking records:

```sql
EXPLAIN ANALYZE
SELECT status, SUM(item_count)::integer
FROM batch_job_trackings
WHERE parent_job_id = 123
GROUP BY status;

-- Typical result: ~5-10ms even with 10k records
```

## Future Enhancements

1. **Retry Failed Batches**
   - Automatically re-enqueue failed batches
   - Track retry count to prevent infinite loops

2. **Dashboard**
   - Real-time visualization of batch progress
   - Crash rate trends
   - Performance metrics

3. **Alerting**
   - Notify on high crash rate
   - Alert on slow batches
   - Warn on increasing failure rate

4. **Batch Splitting**
   - If batch crashes, split into smaller sub-batches
   - Binary search to find problematic annotation
