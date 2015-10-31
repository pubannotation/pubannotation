ThinkingSphinx::Index.define :doc, with: :active_record, delta: true do
  indexes sourcedb, sortable: true
  indexes sourceid, sortable: true
  indexes body, sortable: true
  indexes serial
  indexes projects.id, as: :project_id

  has projects.id, as: :project_id
  set_property enable_star: 1
  set_property min_infix_len: 2
end
