module Exceptions
  class TooManyBackgroundJobsError < StandardError; end

  class JobSuspendError < StandardError
    def initialize(msg = "Job was suspended")
      super(msg)
    end
  end
end
