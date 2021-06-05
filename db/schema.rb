# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20210521012902) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "annotators", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.text     "description"
    t.string   "home",               limit: 255
    t.integer  "user_id"
    t.string   "url",                limit: 255
    t.text     "payload"
    t.integer  "method"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.boolean  "is_public",                      default: false
    t.text     "sample"
    t.integer  "max_text_size"
    t.boolean  "async_protocol",                 default: false
    t.string   "receiver_attribute", limit: 255
    t.string   "new_label",          limit: 255
  end

  add_index "annotators", ["user_id"], name: "index_annotators_on_user_id", using: :btree

  create_table "associate_maintainers", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "associate_maintainers", ["project_id"], name: "index_associate_maintainers_on_project_id", using: :btree
  add_index "associate_maintainers", ["user_id"], name: "index_associate_maintainers_on_user_id", using: :btree

  create_table "attrivutes", force: :cascade do |t|
    t.string   "hid",        limit: 255
    t.integer  "subj_id"
    t.string   "subj_type",  limit: 255
    t.string   "obj",        limit: 255
    t.string   "pred",       limit: 255
    t.integer  "project_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "attrivutes", ["obj"], name: "index_attrivutes_on_obj", using: :btree
  add_index "attrivutes", ["project_id"], name: "index_attrivutes_on_project_id", using: :btree
  add_index "attrivutes", ["subj_id"], name: "index_attrivutes_on_subj_id", using: :btree

  create_table "collection_projects", force: :cascade do |t|
    t.integer  "collection_id"
    t.integer  "project_id"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.boolean  "is_primary",    default: false
  end

  create_table "collections", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.text     "description"
    t.string   "reference",     limit: 255
    t.integer  "user_id"
    t.boolean  "is_sharedtask",             default: false
    t.integer  "accessibility",             default: 1
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.boolean  "is_open",                   default: false
    t.string   "sparql_ep",     limit: 255
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",               default: 0, null: false
    t.integer  "attempts",               default: 0, null: false
    t.text     "handler",                            null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "index_delayed_jobs_on_priority_and_run_at", using: :btree

  create_table "denotations", force: :cascade do |t|
    t.string   "hid",        limit: 255
    t.integer  "doc_id"
    t.integer  "begin"
    t.integer  "end"
    t.string   "obj",        limit: 255
    t.integer  "project_id"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.boolean  "is_block",               default: false
  end

  add_index "denotations", ["doc_id"], name: "index_denotations_on_doc_id", using: :btree
  add_index "denotations", ["project_id"], name: "index_denotations_on_project_id", using: :btree

  create_table "divisions", force: :cascade do |t|
    t.integer  "doc_id"
    t.string   "label",      limit: 255
    t.integer  "begin"
    t.integer  "end"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "divisions", ["doc_id"], name: "index_divisions_on_doc_id", using: :btree

  create_table "docs", force: :cascade do |t|
    t.text     "body"
    t.string   "source",            limit: 255
    t.string   "sourcedb",          limit: 255
    t.string   "sourceid",          limit: 255
    t.integer  "serial"
    t.string   "section",           limit: 255
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.integer  "denotations_num",               default: 0
    t.integer  "relations_num",                 default: 0
    t.integer  "projects_num",                  default: 0
    t.boolean  "flag",                          default: false, null: false
    t.integer  "modifications_num",             default: 0
  end

  add_index "docs", ["denotations_num"], name: "index_docs_on_denotations_num", using: :btree
  add_index "docs", ["projects_num"], name: "index_docs_on_projects_num", using: :btree
  add_index "docs", ["serial"], name: "index_docs_on_serial", using: :btree
  add_index "docs", ["sourcedb", "sourceid"], name: "index_docs_on_sourcedb_and_sourceid", unique: true, using: :btree
  add_index "docs", ["sourcedb"], name: "index_docs_on_sourcedb", using: :btree
  add_index "docs", ["sourceid"], name: "index_docs_on_sourceid", using: :btree

  create_table "editors", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "url",         limit: 255
    t.text     "parameters"
    t.text     "description"
    t.string   "home",        limit: 255
    t.integer  "user_id"
    t.boolean  "is_public",               default: false
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  add_index "editors", ["name"], name: "index_editors_on_name", unique: true, using: :btree
  add_index "editors", ["user_id"], name: "index_editors_on_user_id", using: :btree

  create_table "evaluations", force: :cascade do |t|
    t.integer  "study_project_id"
    t.integer  "reference_project_id"
    t.integer  "evaluator_id"
    t.string   "note",                   limit: 255
    t.text     "result"
    t.integer  "user_id"
    t.boolean  "is_public",                          default: false
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.integer  "soft_match_characters"
    t.integer  "soft_match_words"
    t.text     "denotations_type_match"
    t.text     "relations_type_match"
  end

  add_index "evaluations", ["evaluator_id"], name: "index_evaluations_on_evaluator_id", using: :btree
  add_index "evaluations", ["reference_project_id"], name: "index_evaluations_on_reference_project_id", using: :btree
  add_index "evaluations", ["study_project_id"], name: "index_evaluations_on_study_project_id", using: :btree
  add_index "evaluations", ["user_id"], name: "index_evaluations_on_user_id", using: :btree

  create_table "evaluators", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "home",        limit: 255
    t.text     "description"
    t.integer  "access_type"
    t.string   "url",         limit: 255
    t.integer  "user_id"
    t.boolean  "is_public",               default: false
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
  end

  add_index "evaluators", ["user_id"], name: "index_evaluators_on_user_id", using: :btree

  create_table "jobs", force: :cascade do |t|
    t.integer  "organization_id"
    t.integer  "delayed_job_id"
    t.integer  "num_items"
    t.integer  "num_dones"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "name",              limit: 255
    t.datetime "begun_at"
    t.datetime "ended_at"
    t.datetime "registered_at"
    t.string   "organization_type", limit: 255
  end

  add_index "jobs", ["delayed_job_id"], name: "index_jobs_on_delayed_job_id", using: :btree
  add_index "jobs", ["organization_id"], name: "index_jobs_on_project_id", using: :btree

  create_table "messages", force: :cascade do |t|
    t.text     "body"
    t.integer  "job_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "sourcedb",   limit: 255
    t.string   "sourceid",   limit: 255
    t.integer  "divid"
    t.text     "data"
  end

  add_index "messages", ["job_id", "created_at"], name: "index_messages_on_job_id_and_created_at", using: :btree
  add_index "messages", ["job_id"], name: "index_messages_on_job_id", using: :btree

  create_table "modifications", force: :cascade do |t|
    t.string   "hid",        limit: 255
    t.integer  "obj_id"
    t.string   "obj_type",   limit: 255
    t.string   "pred",       limit: 255
    t.integer  "project_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "modifications", ["obj_id"], name: "index_modifications_on_obj_id", using: :btree
  add_index "modifications", ["project_id"], name: "index_modifications_on_project_id", using: :btree

  create_table "news_notifications", force: :cascade do |t|
    t.string   "title",      limit: 255
    t.string   "category",   limit: 255
    t.string   "body",       limit: 255
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.boolean  "active",                 default: false
  end

  create_table "project_docs", force: :cascade do |t|
    t.integer  "project_id"
    t.integer  "doc_id"
    t.integer  "denotations_num",        default: 0
    t.integer  "relations_num",          default: 0
    t.integer  "modifications_num",      default: 0
    t.datetime "annotations_updated_at"
  end

  add_index "project_docs", ["denotations_num"], name: "index_project_docs_on_denotations_num", using: :btree
  add_index "project_docs", ["doc_id"], name: "index_project_docs_on_doc_id", using: :btree
  add_index "project_docs", ["project_id"], name: "index_project_docs_on_project_id", using: :btree

  create_table "projects", force: :cascade do |t|
    t.string   "name",                         limit: 255
    t.text     "description"
    t.string   "author",                       limit: 255
    t.datetime "created_at",                                                               null: false
    t.datetime "updated_at",                                                               null: false
    t.string   "license",                      limit: 255
    t.string   "reference",                    limit: 255
    t.integer  "accessibility"
    t.integer  "status"
    t.integer  "user_id"
    t.string   "viewer",                       limit: 255
    t.string   "rdfwriter",                    limit: 255
    t.string   "xmlwriter",                    limit: 255
    t.string   "bionlpwriter",                 limit: 255
    t.string   "type",                         limit: 255
    t.integer  "docs_count",                               default: 0
    t.integer  "denotations_num",                          default: 0
    t.integer  "relations_num",                            default: 0
    t.boolean  "annotations_zip_downloadable",             default: true
    t.datetime "annotations_updated_at",                   default: '2016-04-08 06:25:21'
    t.text     "namespaces"
    t.integer  "process"
    t.integer  "annotations_count",                        default: 0
    t.string   "sample",                       limit: 255
    t.boolean  "anonymize",                                default: false,                 null: false
    t.integer  "modifications_num",                        default: 0
    t.string   "textae_config",                limit: 255
    t.integer  "annotator_id"
    t.string   "sparql_ep",                    limit: 255
  end

  add_index "projects", ["name"], name: "index_projects_on_name", unique: true, using: :btree

  create_table "queries", force: :cascade do |t|
    t.string   "title",      limit: 255, default: ""
    t.text     "sparql",                 default: ""
    t.text     "comment"
    t.string   "show_mode",  limit: 255
    t.string   "projects",   limit: 255
    t.integer  "priority",               default: 0,     null: false
    t.boolean  "active",                 default: true,  null: false
    t.integer  "project_id"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.integer  "category",               default: 2
    t.boolean  "reasoning",              default: false
  end

  add_index "queries", ["project_id"], name: "index_queries_on_project_id", using: :btree

  create_table "relations", force: :cascade do |t|
    t.string   "hid",        limit: 255
    t.integer  "subj_id"
    t.string   "subj_type",  limit: 255
    t.integer  "obj_id"
    t.string   "obj_type",   limit: 255
    t.string   "pred",       limit: 255
    t.integer  "project_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "relations", ["obj_id"], name: "index_relations_on_obj_id", using: :btree
  add_index "relations", ["project_id"], name: "index_relations_on_project_id", using: :btree
  add_index "relations", ["subj_id"], name: "index_relations_on_subj_id", using: :btree

  create_table "sequencers", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.text     "description"
    t.string   "home",        limit: 255
    t.integer  "user_id"
    t.string   "url",         limit: 255
    t.text     "parameters"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.boolean  "is_public",               default: false
  end

  add_index "sequencers", ["user_id"], name: "index_sequencers_on_user_id", using: :btree

  create_table "typesettings", force: :cascade do |t|
    t.integer  "doc_id"
    t.string   "style",      limit: 255
    t.integer  "begin"
    t.integer  "end"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "typesettings", ["doc_id"], name: "index_typesettings_on_doc_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "",    null: false
    t.string   "encrypted_password",     limit: 255, default: "",    null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.text     "username",                           default: "",    null: false
    t.boolean  "root",                               default: false
    t.string   "confirmation_token",     limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",      limit: 255
    t.boolean  "manager",                            default: false
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

end
