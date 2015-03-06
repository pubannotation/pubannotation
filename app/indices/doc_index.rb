ThinkingSphinx::Index.define :doc, with: :active_record do
  indexes sourcedb, sortable: true
  indexes sourceid, sortable: true
  indexes body, sortable: true
  indexes serial

  has projects.id, as: :project_id
  set_property enable_star: 1
  set_property min_infix_len: 2
end
