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

ActiveRecord::Schema[7.1].define(version: 2024_01_12_020922) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "annotators", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "home"
    t.integer "user_id"
    t.string "url"
    t.text "payload"
    t.integer "method"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_public", default: false
    t.text "sample"
    t.integer "max_text_size"
    t.boolean "async_protocol", default: false
    t.string "receiver_attribute"
    t.string "new_label"
    t.index ["user_id"], name: "index_annotators_on_user_id"
  end

  create_table "associate_maintainers", force: :cascade do |t|
    t.integer "user_id"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id"], name: "index_associate_maintainers_on_project_id"
    t.index ["user_id"], name: "index_associate_maintainers_on_user_id"
  end

  create_table "attrivutes", id: :serial, force: :cascade do |t|
    t.string "hid"
    t.integer "subj_id"
    t.string "subj_type"
    t.string "obj"
    t.string "pred"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "doc_id"
    t.index ["doc_id"], name: "index_attrivutes_on_doc_id"
    t.index ["obj"], name: "index_attrivutes_on_obj"
    t.index ["project_id"], name: "index_attrivutes_on_project_id"
    t.index ["subj_id"], name: "index_attrivutes_on_subj_id"
  end

  create_table "blocks", force: :cascade do |t|
    t.string "hid"
    t.integer "doc_id"
    t.integer "begin"
    t.integer "end"
    t.string "obj"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "collection_projects", id: :serial, force: :cascade do |t|
    t.integer "collection_id"
    t.integer "project_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "is_primary", default: false
    t.boolean "is_secondary", default: false
  end

  create_table "collections", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "reference"
    t.integer "user_id"
    t.boolean "is_sharedtask", default: false
    t.integer "accessibility", default: 1
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "is_open", default: false
    t.string "sparql_ep"
  end

  create_table "denotations", force: :cascade do |t|
    t.string "hid"
    t.integer "doc_id"
    t.integer "begin"
    t.integer "end"
    t.string "obj"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_block", default: false
    t.index ["doc_id"], name: "index_denotations_on_doc_id"
    t.index ["project_id"], name: "index_denotations_on_project_id"
  end

  create_table "divisions", id: :serial, force: :cascade do |t|
    t.integer "doc_id"
    t.string "label"
    t.integer "begin"
    t.integer "end"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["doc_id"], name: "index_divisions_on_doc_id"
  end

  create_table "docs", force: :cascade do |t|
    t.text "body"
    t.string "source"
    t.string "sourcedb"
    t.string "sourceid"
    t.integer "serial"
    t.string "section"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "denotations_num", default: 0
    t.integer "relations_num", default: 0
    t.integer "projects_num", default: 0
    t.boolean "flag", default: false, null: false
    t.integer "modifications_num", default: 0
    t.integer "blocks_num", default: 0
    t.index ["denotations_num"], name: "index_docs_on_denotations_num"
    t.index ["projects_num"], name: "index_docs_on_projects_num"
    t.index ["serial"], name: "index_docs_on_serial"
    t.index ["sourcedb", "sourceid"], name: "index_docs_on_sourcedb_and_sourceid", unique: true
    t.index ["sourcedb"], name: "index_docs_on_sourcedb"
    t.index ["sourceid"], name: "index_docs_on_sourceid"
  end

  create_table "editors", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.text "parameters"
    t.text "description"
    t.string "home"
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["name"], name: "index_editors_on_name", unique: true
    t.index ["user_id"], name: "index_editors_on_user_id"
  end

  create_table "evaluations", id: :serial, force: :cascade do |t|
    t.integer "study_project_id"
    t.integer "reference_project_id"
    t.integer "evaluator_id"
    t.string "note"
    t.text "result"
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "soft_match_characters"
    t.integer "soft_match_words"
    t.text "denotations_type_match"
    t.text "relations_type_match"
    t.index ["evaluator_id"], name: "index_evaluations_on_evaluator_id"
    t.index ["reference_project_id"], name: "index_evaluations_on_reference_project_id"
    t.index ["study_project_id"], name: "index_evaluations_on_study_project_id"
    t.index ["user_id"], name: "index_evaluations_on_user_id"
  end

  create_table "evaluators", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "home"
    t.text "description"
    t.integer "access_type"
    t.string "url"
    t.integer "user_id"
    t.boolean "is_public", default: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["user_id"], name: "index_evaluators_on_user_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.integer "organization_id"
    t.integer "num_items"
    t.integer "num_dones"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "name"
    t.datetime "begun_at", precision: nil
    t.datetime "ended_at", precision: nil
    t.datetime "registered_at", precision: nil
    t.string "organization_type"
    t.string "active_job_id"
    t.string "queue_name"
    t.boolean "suspend_flag", default: false
    t.index ["organization_id"], name: "index_jobs_on_organization_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body"
    t.integer "job_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "sourcedb"
    t.string "sourceid"
    t.integer "divid"
    t.text "data"
    t.string "organization_type"
    t.bigint "organization_id"
    t.index ["job_id", "created_at"], name: "index_messages_on_job_id_and_created_at"
    t.index ["job_id"], name: "index_messages_on_job_id"
    t.index ["organization_type", "organization_id"], name: "index_messages_on_organization"
  end

  create_table "modifications", force: :cascade do |t|
    t.string "hid"
    t.integer "obj_id"
    t.string "obj_type"
    t.string "pred"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["obj_id"], name: "index_modifications_on_obj_id"
    t.index ["project_id"], name: "index_modifications_on_project_id"
  end

  create_table "news_notifications", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "category"
    t.string "body"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "active", default: false
  end

  create_table "paragraph_attrivutes", force: :cascade do |t|
    t.bigint "division_id", null: false
    t.bigint "attrivute_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attrivute_id"], name: "index_paragraph_attrivutes_on_attrivute_id"
    t.index ["division_id"], name: "index_paragraph_attrivutes_on_division_id"
  end

  create_table "paragraph_denotations", force: :cascade do |t|
    t.bigint "division_id", null: false
    t.bigint "denotation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["denotation_id"], name: "index_paragraph_denotations_on_denotation_id"
    t.index ["division_id"], name: "index_paragraph_denotations_on_division_id"
  end

  create_table "project_docs", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.integer "doc_id"
    t.integer "denotations_num", default: 0
    t.integer "relations_num", default: 0
    t.integer "modifications_num", default: 0
    t.datetime "annotations_updated_at", precision: nil
    t.integer "blocks_num", default: 0
    t.boolean "flag", default: false
    t.index ["denotations_num"], name: "index_project_docs_on_denotations_num"
    t.index ["doc_id"], name: "index_project_docs_on_doc_id"
    t.index ["project_id"], name: "index_project_docs_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "author"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "license"
    t.string "reference"
    t.integer "accessibility"
    t.integer "status"
    t.integer "user_id"
    t.string "viewer"
    t.string "rdfwriter"
    t.string "xmlwriter"
    t.string "bionlpwriter"
    t.string "type"
    t.integer "docs_count", default: 0
    t.integer "denotations_num", default: 0
    t.integer "relations_num", default: 0
    t.boolean "annotations_zip_downloadable", default: true
    t.datetime "annotations_updated_at", precision: nil, default: "2016-04-08 06:25:21"
    t.text "namespaces"
    t.integer "process"
    t.integer "annotations_count", default: 0
    t.string "sample"
    t.boolean "anonymize", default: false, null: false
    t.integer "modifications_num", default: 0
    t.string "textae_config"
    t.integer "annotator_id"
    t.string "sparql_ep"
    t.text "analysis"
    t.integer "blocks_num", default: 0
    t.json "docs_stat", default: {}
    t.index ["annotator_id"], name: "index_projects_on_annotator_id"
    t.index ["name"], name: "index_projects_on_name", unique: true
  end

  create_table "queries", id: :serial, force: :cascade do |t|
    t.string "title", default: ""
    t.text "sparql", default: ""
    t.text "comment"
    t.string "show_mode"
    t.string "projects"
    t.integer "priority", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.integer "organization_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "category", default: 2
    t.boolean "reasoning", default: false
    t.string "organization_type", default: "Project"
    t.index ["organization_id"], name: "index_queries_on_organization_id"
  end

  create_table "relations", force: :cascade do |t|
    t.string "hid"
    t.integer "subj_id"
    t.string "subj_type"
    t.integer "obj_id"
    t.string "obj_type"
    t.string "pred"
    t.integer "project_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "doc_id"
    t.index ["doc_id"], name: "index_relations_on_doc_id"
    t.index ["obj_id"], name: "index_relations_on_obj_id"
    t.index ["project_id"], name: "index_relations_on_project_id"
    t.index ["subj_id"], name: "index_relations_on_subj_id"
  end

  create_table "sentence_attrivutes", force: :cascade do |t|
    t.bigint "block_id", null: false
    t.bigint "attrivute_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attrivute_id"], name: "index_sentence_attrivutes_on_attrivute_id"
    t.index ["block_id"], name: "index_sentence_attrivutes_on_block_id"
  end

  create_table "sentence_denotations", force: :cascade do |t|
    t.bigint "block_id", null: false
    t.bigint "denotation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["block_id"], name: "index_sentence_denotations_on_block_id"
    t.index ["denotation_id"], name: "index_sentence_denotations_on_denotation_id"
  end

  create_table "sequencers", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "home"
    t.integer "user_id"
    t.string "url"
    t.text "parameters"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "is_public", default: false
    t.index ["user_id"], name: "index_sequencers_on_user_id"
  end

  create_table "typesettings", id: :serial, force: :cascade do |t|
    t.integer "doc_id"
    t.string "style"
    t.integer "begin"
    t.integer "end"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["doc_id"], name: "index_typesettings_on_doc_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "username", default: "", null: false
    t.boolean "root", default: false
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.boolean "manager", default: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "attrivutes", "docs"
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
