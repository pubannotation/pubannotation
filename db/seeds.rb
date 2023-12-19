# This seed only for development environment
return if Rails.env.production?

User.create! username: 'admin',
             email: 'admin@pubannotatio.org',
             password: 'abc123',
             password_confirmation: 'abc123',
             confirmed_at: Time.now,
             root: true,
             manager: true

Project.create! name: 'First',
                user: User.first,
                accessibility: 1

# To Avoid initialize error, Create admin project.
# Note that if the id is missing teeth, the test will fail in a CI environment.
i = 0
loop do
  project = Project.create! name: "ForAdmin#{i}",
                            user: User.first,
                            accessibility: 0
  i += 1
  break if project.id == Pubann::Application.config.admin_project_id
end

Sequencer.create! name: 'PMC',
                  url: 'http://pubmed-sequencer.pubannotation.org/?sourcedb=PMC',
                  parameters: { 'sourceid' => '_sourceid_' },
                  user: User.first
