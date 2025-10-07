# System Crash Analysis - October 6, 2025

## Summary
The `StoreAnnotationsCollectionUploadJob` caused a complete system crash due to **infinite loops** in queue throttling logic, combined with massive memory consumption from processing large annotation payloads.

## Root Cause

### Primary Issue: Infinite Loop in Queue Throttling
**Location**: `app/jobs/store_annotations_collection_upload_job.rb:228-248` (original code)

The `wait_for_queue_space` method had an infinite loop with no timeout:

```ruby
def wait_for_queue_space
  loop do
    queue = Sidekiq::Queue.new('general')
    current_queue_size = queue.size

    if current_queue_size >= MAX_QUEUE_SIZE  # 100
      update_progress_from_tracking
      sleep(0.5)
      next  # ← INFINITE LOOP if queue stays full
    end
    break
  end
end
```

**What Happened:**
1. Parent job enqueued batch jobs to process annotations
2. Child jobs processed **massive annotation objects** (16KB+ per log entry)
3. Queue stayed consistently full (≥100 jobs) due to slow processing
4. Parent job entered infinite loop, running DB queries every 0.5 seconds
5. System resources exhausted: memory + DB connections + disk I/O
6. **Complete system crash at 08:29:03**

### Evidence from Logs:
- **sidekiq1.log**: 281MB with only 17,473 lines = ~16KB per line
- Last timestamp before crash: `2025-10-06T08:29:03.331Z`
- Massive annotation payloads with multi-kilobyte text fields being logged
- Multiple batch jobs processing simultaneously

### Secondary Issue: Another Infinite Loop
**Location**: `app/jobs/store_annotations_collection_upload_job.rb:290-330` (original code)

The `wait_for_batch_jobs_completion` method also had no maximum wait time and would loop forever if:
- `total_items` was 0
- Batch jobs never completed
- All jobs crashed/failed but parent didn't detect it

## Fixes Implemented

### Fix 1: Queue Throttling Timeout (lines 228-264)
Added maximum iteration limit and increased sleep duration:

```ruby
def wait_for_queue_space
  max_wait_iterations = 150  # 5 minutes max (150 * 2s)
  iterations = 0

  loop do
    queue = Sidekiq::Queue.new('general')
    current_queue_size = queue.size

    if current_queue_size >= MAX_QUEUE_SIZE
      iterations += 1

      # Prevent infinite loop - abort if queue stays full too long
      if iterations >= max_wait_iterations
        error_msg = "Sidekiq queue has been full for #{max_wait_iterations * 2} seconds..."
        Rails.logger.error "[#{self.class.name}] #{error_msg}"
        raise error_msg
      end

      update_progress_from_tracking
      sleep(2)  # Increased from 0.5s to reduce system load
      next
    end
    break
  end
end
```

**Benefits:**
- **Prevents infinite loops**: Job aborts after 5 minutes of full queue
- **Reduces system load**: Sleep increased from 0.5s to 2s (4x reduction in DB queries)
- **Better visibility**: Logs iteration count for monitoring

### Fix 2: Batch Completion Timeout (lines 284-341)
Added absolute maximum wait time:

```ruby
def wait_for_batch_jobs_completion
  start_time = Time.current
  max_wait_time = 2.hours  # Absolute maximum wait time

  loop do
    elapsed_time = Time.current - start_time
    if elapsed_time > max_wait_time
      error_msg = "Batch jobs have not completed after #{max_wait_time.inspect}..."
      Rails.logger.error "[#{self.class.name}] #{error_msg}"
      raise error_msg
    end

    # ... rest of logic ...
    sleep(2)  # Increased from 0.5s to reduce system load
  end
end
```

**Benefits:**
- **Prevents indefinite waiting**: Job aborts after 2 hours maximum
- **Reduces system load**: Sleep increased from 0.5s to 2s
- **Fail-fast behavior**: Better than silent hanging

## Impact Assessment

### Before Fixes:
- ❌ Infinite loops could run forever
- ❌ DB queries every 0.5s during blocking
- ❌ No circuit breaker for overloaded system
- ❌ Complete system crash possible

### After Fixes:
- ✅ Jobs abort after defined timeout (5 min for queue, 2 hrs for completion)
- ✅ 4x reduction in DB query frequency (2s vs 0.5s sleep)
- ✅ Fail-fast with clear error messages
- ✅ System protected from resource exhaustion

## Test Results
All tests passing after fixes:
- `store_annotations_collection_upload_job_spec.rb`: 8 examples, 0 failures
- `store_annotations_collection_upload_job_tracking_spec.rb`: 15 examples, 0 failures

## Recommendations

1. **Monitor queue sizes**: Add alerting when Sidekiq queue > 80 jobs
2. **Optimize payloads**: Consider reducing annotation text in job arguments
3. **Add memory limits**: Configure Sidekiq worker memory limits
4. **Add circuit breaker**: Auto-pause jobs when system load is high
5. **Review other loops**: Audit codebase for similar infinite loop patterns

## Files Modified
- `app/jobs/store_annotations_collection_upload_job.rb`
  - Lines 228-264: Fixed `wait_for_queue_space` infinite loop
  - Lines 284-341: Fixed `wait_for_batch_jobs_completion` infinite loop
