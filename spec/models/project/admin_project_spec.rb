require 'rails_helper'

RSpec.describe Project do
  it 'reads the current admin project counts after another process changes them' do
    admin_project = create(:project, id: Pubann::Admin::ProjectId)
    expect(Project.docs_count).to eq(admin_project.docs_count)

    Project.where(id: admin_project.id).update_all(docs_count: 42)

    expect(Project.docs_count).to eq(42)
  end
end
