class RenameColumnRelsubIdToSubjIdAndRelsubTypeToSubjType < ActiveRecord::Migration
  def up
    remove_index    :relations, :relsub_id
    rename_column   :relations, :relsub_id, :subj_id
    add_index       :relations, :subj_id
    rename_column   :relations, :relsub_type, :subj_type
  end

  def down
    remove_index    :relations, :subj_id
    rename_column   :relations, :subj_id, :relsub_id
    add_index       :relations, :relsub_id
    rename_column   :relations, :subj_type, :relsub_type
  end
end
