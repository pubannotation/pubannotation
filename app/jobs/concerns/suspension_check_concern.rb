# frozen_string_literal: true

module SuspensionCheckConcern
  extend ActiveSupport::Concern

  def start_suspension_monitoring(pool, job)
    @suspension_stop_flag = Concurrent::AtomicBoolean.new(false)

    Thread.new do
      while !@suspension_stop_flag.true?
        begin
          # File check doesn't need DB connection
          if job&.suspended?
            pool.kill # Immediately kill pool to stop all queued work
            # Only acquire DB connection for adding message
            ActiveRecord::Base.connection_pool.with_connection do
              job&.add_message(body: "Job suspended")
            end
            break # Exit checker loop since job is suspended
          end
        rescue => e
          # Ignore errors in background checker to avoid disrupting main job
        end
        sleep(2) # Check every 2 seconds
      end
    end
  end

  def stop_suspension_monitoring(checker_thread)
    # Stop background checker AFTER all threads are done
    @suspension_stop_flag.make_true
    checker_thread.join(5) # Wait up to 5 seconds for checker to stop
    
    # Ensure we don't access job after checker thread might still be using it
    if checker_thread.alive?
      checker_thread.kill # Force kill if it didn't stop gracefully
    end
  end
end