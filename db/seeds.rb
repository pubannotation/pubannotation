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

Project.create! id: Pubann::Application.config.admin_project_id,
                name: 'ForAdmin',
                user: User.first,
                accessibility: 0

Sequencer.create! name: 'PMC',
                  url: 'http://pubmed-sequencer.pubannotation.org/?sourcedb=PMC',
                  parameters: { 'sourceid' => '_sourceid_' },
                  user: User.first
