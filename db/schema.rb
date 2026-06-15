# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_15_070604) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "annotation_receptions", force: :cascade do |t|
    t.bigint "annotator_id"
    t.datetime "created_at", null: false
    t.json "hdoc_metadata", default: {}
    t.bigint "job_id"
    t.json "options", default: {}
    t.bigint "project_id"
    t.datetime "updated_at", null: false
    t.string "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["annotator_id"], name: "index_annotation_receptions_on_annotator_id"
    t.index ["job_id"], name: "index_annotation_receptions_on_job_id"
    t.index ["project_id"], name: "index_annotation_receptions_on_project_id"
  end

  create_table "annotators", force: :cascade do |t|
    t.boolean "async_protocol", default: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "home"
    t.boolean "is_public", default: false
    t.integer "max_text_size"
    t.integer "method"
    t.string "name"
    t.string "new_label"
    t.text "payload"
    t.string "receiver_attribute"
    t.text "sample"
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id"
    t.index ["user_id"], name: "index_annotators_on_user_id"
  end

  create_table "associate_maintainers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["project_id"], name: "index_associate_maintainers_on_project_id"
    t.index ["user_id"], name: "index_associate_maintainers_on_user_id"
  end

  create_table "attrivutes", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.bigint "doc_id"
    t.string "hid"
    t.string "obj"
    t.string "pred"
    t.integer "project_id"
    t.integer "subj_id"
    t.string "subj_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["doc_id"], name: "index_attrivutes_on_doc_id"
    t.index ["obj"], name: "index_attrivutes_on_obj"
    t.index ["project_id", "doc_id"], name: "index_attrivutes_on_project_id_and_doc_id"
    t.index ["project_id"], name: "index_attrivutes_on_project_id"
    t.index ["subj_id"], name: "index_attrivutes_on_subj_id"
  end

  create_table "batch_job_trackings", force: :cascade do |t|
    t.integer "annotation_objects_count"
    t.string "child_job_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.json "doc_identifiers", default: [], null: false
    t.text "error_message"
    t.integer "item_count", default: 0, null: false
    t.bigint "memory_estimation"
    t.bigint "parent_job_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["child_job_id"], name: "index_batch_tracking_on_child_job"
    t.index ["created_at"], name: "index_batch_tracking_on_created_at"
    t.index ["parent_job_id", "status"], name: "index_batch_tracking_on_parent_and_status"
    t.index ["parent_job_id"], name: "index_batch_tracking_on_parent_job"
  end

  create_table "blocks", force: :cascade do |t|
    t.integer "begin"
    t.datetime "created_at", precision: nil, null: false
    t.integer "doc_id"
    t.integer "end"
    t.string "hid"
    t.string "obj"
    t.integer "project_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["doc_id"], name: "index_blocks_on_doc_id"
    t.index ["project_id", "doc_id"], name: "index_blocks_on_project_id_and_doc_id"
    t.index ["project_id"], name: "index_blocks_on_project_id"
  end

  create_table "collection_projects", id: :serial, force: :cascade do |t|
    t.integer "collection_id"
    t.datetime "created_at", precision: nil
    t.boolean "is_primary", default: false
    t.boolean "is_secondary", default: false
    t.integer "project_id"
    t.datetime "updated_at", precision: nil
  end

  create_table "collections", id: :serial, force: :cascade do |t|
    t.integer "accessibility", default: 1
    t.datetime "created_at", precision: nil
    t.text "description"
    t.boolean "is_open", default: false
    t.boolean "is_sharedtask", default: false
    t.string "name"
    t.string "reference"
    t.string "sparql_ep"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
  end

  create_table "denotations", force: :cascade do |t|
    t.integer "begin"
    t.datetime "created_at", null: false
    t.integer "doc_id"
    t.integer "end"
    t.string "hid"
    t.boolean "is_block", default: false
    t.string "obj"
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.index ["begin", "end"], name: "index_denotations_on_begin_and_end"
    t.index ["doc_id"], name: "index_denotations_on_doc_id"
    t.index ["project_id", "doc_id"], name: "index_denotations_on_project_id_and_doc_id"
    t.index ["project_id"], name: "index_denotations_on_project_id"
  end

  create_table "divisions", id: :serial, force: :cascade do |t|
    t.integer "begin"
    t.datetime "created_at", precision: nil
    t.integer "doc_id"
    t.integer "end"
    t.string "label"
    t.datetime "updated_at", precision: nil
    t.index ["doc_id"], name: "index_divisions_on_doc_id"
  end

  create_table "docs", force: :cascade do |t|
    t.integer "blocks_num", default: 0
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "denotations_num", default: 0
    t.boolean "flag", default: false, null: false
    t.string "media_sourcedb"
    t.string "media_sourceid"
    t.integer "modifications_num", default: 0
    t.integer "projects_num", default: 0
    t.integer "relations_num", default: 0
    t.string "section"
    t.integer "serial"
    t.string "source"
    t.string "sourcedb"
    t.string "sourceid"
    t.datetime "updated_at", null: false
    t.index ["denotations_num"], name: "index_docs_on_denotations_num"
    t.index ["media_sourcedb", "media_sourceid"], name: "index_docs_on_media_sourcedb_and_media_sourceid"
    t.index ["projects_num"], name: "index_docs_on_projects_num"
    t.index ["serial"], name: "index_docs_on_serial"
    t.index ["sourcedb", "sourceid"], name: "index_docs_on_sourcedb_and_sourceid", unique: true
    t.index ["sourcedb"], name: "index_docs_on_sourcedb"
    t.index ["sourceid"], name: "index_docs_on_sourceid"
  end

  create_table "editors", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "home"
    t.boolean "is_public", default: false
    t.string "name"
    t.text "parameters"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.integer "user_id"
    t.index ["name"], name: "index_editors_on_name", unique: true
    t.index ["user_id"], name: "index_editors_on_user_id"
  end

  create_table "evaluations", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "denotations_type_match"
    t.integer "evaluator_id"
    t.boolean "is_public", default: false
    t.string "note"
    t.integer "reference_project_id"
    t.text "relations_type_match"
    t.text "result"
    t.integer "soft_match_characters"
    t.integer "soft_match_words"
    t.integer "study_project_id"
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.index ["evaluator_id"], name: "index_evaluations_on_evaluator_id"
    t.index ["reference_project_id"], name: "index_evaluations_on_reference_project_id"
    t.index ["study_project_id"], name: "index_evaluations_on_study_project_id"
    t.index ["user_id"], name: "index_evaluations_on_user_id"
  end

  create_table "evaluators", id: :serial, force: :cascade do |t|
    t.integer "access_type"
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "home"
    t.boolean "is_public", default: false
    t.string "name"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.integer "user_id"
    t.index ["user_id"], name: "index_evaluators_on_user_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.datetime "begun_at"
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "name"
    t.integer "num_dones"
    t.integer "num_items"
    t.integer "organization_id"
    t.string "organization_type"
    t.string "queue_name"
    t.datetime "registered_at"
    t.boolean "suspend_flag", default: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_jobs_on_organization_id"
  end

  create_table "media", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "media_type"
    t.string "sourcedb"
    t.string "sourceid"
    t.datetime "updated_at", null: false
    t.index ["sourcedb", "sourceid"], name: "index_media_on_sourcedb_and_sourceid", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.text "data"
    t.integer "divid"
    t.integer "job_id"
    t.bigint "organization_id"
    t.string "organization_type"
    t.string "sourcedb"
    t.string "sourceid"
    t.datetime "updated_at", null: false
    t.index ["job_id", "created_at"], name: "index_messages_on_job_id_and_created_at"
    t.index ["job_id"], name: "index_messages_on_job_id"
    t.index ["organization_type", "organization_id"], name: "index_messages_on_organization"
  end

  create_table "modifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hid"
    t.integer "obj_id"
    t.string "obj_type"
    t.string "pred"
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.index ["obj_id"], name: "index_modifications_on_obj_id"
    t.index ["project_id"], name: "index_modifications_on_project_id"
  end

  create_table "news_notifications", id: :serial, force: :cascade do |t|
    t.boolean "active", default: false
    t.string "body"
    t.string "category"
    t.datetime "created_at", precision: nil
    t.string "title"
    t.datetime "updated_at", precision: nil
  end

  create_table "paragraph_attrivutes", force: :cascade do |t|
    t.bigint "attrivute_id", null: false
    t.datetime "created_at", null: false
    t.bigint "division_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attrivute_id"], name: "index_paragraph_attrivutes_on_attrivute_id"
    t.index ["division_id"], name: "index_paragraph_attrivutes_on_division_id"
  end

  create_table "paragraph_denotations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "denotation_id", null: false
    t.bigint "division_id", null: false
    t.datetime "updated_at", null: false
    t.index ["denotation_id"], name: "index_paragraph_denotations_on_denotation_id"
    t.index ["division_id"], name: "index_paragraph_denotations_on_division_id"
  end

  create_table "project_docs", id: :serial, force: :cascade do |t|
    t.datetime "annotations_updated_at", precision: nil
    t.integer "blocks_num", default: 0
    t.integer "denotations_num", default: 0
    t.integer "doc_id"
    t.boolean "flag", default: false
    t.integer "modifications_num", default: 0
    t.integer "project_id"
    t.integer "relations_num", default: 0
    t.index ["denotations_num"], name: "index_project_docs_on_denotations_num"
    t.index ["doc_id"], name: "index_project_docs_on_doc_id"
    t.index ["project_id", "doc_id"], name: "index_project_docs_on_project_id_and_doc_id", unique: true
    t.index ["project_id"], name: "index_project_docs_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "accessibility"
    t.text "analysis"
    t.integer "annotations_count", default: 0
    t.datetime "annotations_updated_at", default: "2016-04-08 06:25:21"
    t.boolean "annotations_zip_downloadable", default: true
    t.integer "annotator_id"
    t.boolean "anonymize", default: false, null: false
    t.string "author"
    t.string "bionlpwriter"
    t.integer "blocks_num", default: 0
    t.datetime "created_at", null: false
    t.integer "denotations_num", default: 0
    t.text "description"
    t.integer "docs_count", default: 0
    t.json "docs_stat", default: {}
    t.string "license"
    t.integer "modifications_num", default: 0
    t.string "name"
    t.text "namespaces"
    t.integer "process"
    t.string "rdfwriter"
    t.string "reference"
    t.integer "relations_num", default: 0
    t.string "sample"
    t.string "sparql_ep"
    t.integer "status"
    t.string "textae_config"
    t.string "type"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "viewer"
    t.string "xmlwriter"
    t.index ["annotator_id"], name: "index_projects_on_annotator_id"
    t.index ["name"], name: "index_projects_on_name", unique: true
  end

  create_table "queries", id: :serial, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "category", default: 2
    t.text "comment"
    t.datetime "created_at", precision: nil
    t.integer "organization_id"
    t.string "organization_type", default: "Project"
    t.integer "priority", default: 0, null: false
    t.string "projects"
    t.boolean "reasoning", default: false
    t.string "show_mode"
    t.text "sparql", default: ""
    t.string "title", default: ""
    t.datetime "updated_at", precision: nil
    t.index ["organization_id"], name: "index_queries_on_organization_id"
  end

  create_table "relations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "doc_id"
    t.string "hid"
    t.integer "obj_id"
    t.string "obj_type"
    t.string "pred"
    t.integer "project_id"
    t.integer "subj_id"
    t.string "subj_type"
    t.datetime "updated_at", null: false
    t.index ["doc_id"], name: "index_relations_on_doc_id"
    t.index ["obj_id"], name: "index_relations_on_obj_id"
    t.index ["project_id", "doc_id"], name: "index_relations_on_project_id_and_doc_id"
    t.index ["project_id"], name: "index_relations_on_project_id"
    t.index ["subj_id"], name: "index_relations_on_subj_id"
  end

  create_table "sentence_attrivutes", force: :cascade do |t|
    t.bigint "attrivute_id", null: false
    t.bigint "block_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attrivute_id"], name: "index_sentence_attrivutes_on_attrivute_id"
    t.index ["block_id"], name: "index_sentence_attrivutes_on_block_id"
  end

  create_table "sentence_denotations", force: :cascade do |t|
    t.bigint "block_id", null: false
    t.datetime "created_at", null: false
    t.bigint "denotation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_sentence_denotations_on_block_id"
    t.index ["denotation_id"], name: "index_sentence_denotations_on_denotation_id"
  end

  create_table "sequencers", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.text "description"
    t.string "home"
    t.boolean "is_public", default: false
    t.string "name"
    t.text "parameters"
    t.datetime "updated_at", precision: nil
    t.string "url"
    t.integer "user_id"
    t.index ["user_id"], name: "index_sequencers_on_user_id"
  end

  create_table "textae_annotations", force: :cascade do |t|
    t.text "annotation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", default: -> { "gen_random_uuid()" }, null: false
  end

  create_table "typesettings", id: :serial, force: :cascade do |t|
    t.integer "begin"
    t.datetime "created_at", precision: nil
    t.integer "doc_id"
    t.integer "end"
    t.string "style"
    t.datetime "updated_at", precision: nil
    t.index ["doc_id"], name: "index_typesettings_on_doc_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.boolean "manager", default: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.boolean "root", default: false
    t.integer "sign_in_count", default: 0
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.text "username", default: "", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "annotation_receptions", "annotators"
  add_foreign_key "annotation_receptions", "jobs"
  add_foreign_key "annotation_receptions", "projects"
  add_foreign_key "attrivutes", "docs"
  add_foreign_key "batch_job_trackings", "jobs", column: "parent_job_id", on_delete: :cascade
  add_foreign_key "paragraph_attrivutes", "attrivutes"
  add_foreign_key "paragraph_attrivutes", "divisions"
  add_foreign_key "paragraph_denotations", "denotations"
  add_foreign_key "paragraph_denotations", "divisions"
  add_foreign_key "relations", "docs"
  add_foreign_key "sentence_attrivutes", "attrivutes"
  add_foreign_key "sentence_attrivutes", "blocks"
  add_foreign_key "sentence_denotations", "blocks"
  add_foreign_key "sentence_denotations", "denotations"
end
