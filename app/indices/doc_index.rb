ThinkingSphinx::Index.define :doc, with: :active_record, delta: true do
  indexes sourcedb, sortable: true
  indexes sourceid, sortable: true
  indexes body, sortable: true
  indexes projects.id, as: :project_id

  has projects.id, as: :project_id
  set_property enable_star: 1
  set_property min_prefix_len: 3
  set_property max_substring_len: 6
end
