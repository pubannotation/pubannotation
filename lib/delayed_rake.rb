class DelayedRake < Struct.new(:task, :options)
  def perform
    env_options = ''
    options && options.stringify_keys!.each do |key, value|
      env_options << " #{key.upcase}='#{value}'"
    end
    ########################################################################
    # Delayed::Job.enqueue(DelayedRake.new("elasticsearch:import:model", class: 'Expression', scope: 'diff'))
    ########################################################################
    system("cd #{Rails.root} && bundle exec rake environment #{task} #{env_options} >> log/delayed_rake.log")
  end
end
