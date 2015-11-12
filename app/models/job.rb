class Job < ActiveRecord::Base
  belongs_to :project
  belongs_to :delayed_job
  has_many :messages, :dependent => :destroy
  attr_accessible :name, :num_dones, :num_items, :project_id, :delayed_job_id

  def destroy_if_not_running
    delayed_job = begin
      Delayed::Job.find(self.delayed_job_id)
    rescue
      nil
    end

    if delayed_job.nil?
      self.destroy
    elsif delayed_job.locked_at.nil? || !delayed_job.failed_at.nil?
      delayed_job.delete 
      self.destroy
    end
  end
end
