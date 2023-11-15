class AddJobReferenceToMessages < ActiveRecord::Migration[7.0]
  def up
    add_reference :messages, :organization, polymorphic: true

    execute <<-SQL.squish
      UPDATE messages
      SET organization_id = jobs.organization_id, organization_type = jobs.organization_type
      FROM jobs
      WHERE messages.job_id = jobs.id
    SQL
  end
  def down
    remove_reference :messages, :organization, polymorphic:true
  end
end
