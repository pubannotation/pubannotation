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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20201202081620) do

  create_table "annotators", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "home"
    t.integer  "user_id"
    t.string   "url"
    t.text     "payload"
    t.integer  "method"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.boolean  "is_public",          :default => false
    t.text     "sample"
    t.integer  "max_text_size"
    t.boolean  "async_protocol",     :default => false
    t.string   "receiver_attribute"
    t.string   "new_label"
  end

  add_index "annotators", ["user_id"], :name => "index_annotators_on_user_id"

  create_table "associate_maintainers", :force => true do |t|
    t.integer  "user_id"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "associate_maintainers", ["project_id"], :name => "index_associate_maintainers_on_project_id"
  add_index "associate_maintainers", ["user_id"], :name => "index_associate_maintainers_on_user_id"

  create_table "attrivutes", :force => true do |t|
    t.string   "hid"
    t.integer  "subj_id"
    t.string   "subj_type"
    t.string   "obj"
    t.string   "pred"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "attrivutes", ["obj"], :name => "index_attrivutes_on_obj"
  add_index "attrivutes", ["project_id"], :name => "index_attrivutes_on_project_id"
  add_index "attrivutes", ["subj_id"], :name => "index_attrivutes_on_subj_id"

  create_table "collection_projects", :force => true do |t|
    t.integer  "collection_id"
    t.integer  "project_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "collections", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "reference"
    t.integer  "user_id"
    t.boolean  "is_sharedtask", :default => false
    t.integer  "accessibility", :default => 1
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
    t.boolean  "is_open",       :default => false
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0, :null => false
    t.integer  "attempts",   :default => 0, :null => false
    t.text     "handler",                   :null => false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "index_delayed_jobs_on_priority_and_run_at"

  create_table "denotations", :force => true do |t|
    t.string   "hid"
    t.integer  "doc_id"
    t.integer  "begin"
    t.integer  "end"
    t.string   "obj"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "denotations", ["doc_id"], :name => "index_denotations_on_doc_id"
  add_index "denotations", ["project_id"], :name => "index_denotations_on_project_id"

  create_table "divisions", :force => true do |t|
    t.integer  "doc_id"
    t.string   "label"
    t.integer  "begin"
    t.integer  "end"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "docs", :force => true do |t|
    t.text     "body"
    t.string   "source"
    t.string   "sourcedb"
    t.string   "sourceid"
    t.integer  "serial"
    t.string   "section"
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
    t.integer  "denotations_num",   :default => 0
    t.integer  "relations_num",     :default => 0
    t.integer  "projects_num",      :default => 0
    t.boolean  "flag",              :default => false, :null => false
    t.integer  "modifications_num", :default => 0
  end

  add_index "docs", ["denotations_num"], :name => "index_docs_on_denotations_num"
  add_index "docs", ["projects_num"], :name => "index_docs_on_projects_num"
  add_index "docs", ["serial"], :name => "index_docs_on_serial"
  add_index "docs", ["sourcedb"], :name => "index_docs_on_sourcedb"
  add_index "docs", ["sourceid"], :name => "index_docs_on_sourceid"

  create_table "editors", :force => true do |t|
    t.string   "name"
    t.string   "url"
    t.text     "parameters"
    t.text     "description"
    t.string   "home"
    t.integer  "user_id"
    t.boolean  "is_public",   :default => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
  end

  add_index "editors", ["name"], :name => "index_editors_on_name", :unique => true
  add_index "editors", ["user_id"], :name => "index_editors_on_user_id"

  create_table "evaluations", :force => true do |t|
    t.integer  "study_project_id"
    t.integer  "reference_project_id"
    t.integer  "evaluator_id"
    t.string   "note"
    t.text     "result"
    t.integer  "user_id"
    t.boolean  "is_public",              :default => false
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.integer  "soft_match_characters"
    t.integer  "soft_match_words"
    t.text     "denotations_type_match"
    t.text     "relations_type_match"
  end

  add_index "evaluations", ["evaluator_id"], :name => "index_evaluations_on_evaluator_id"
  add_index "evaluations", ["reference_project_id"], :name => "index_evaluations_on_reference_project_id"
  add_index "evaluations", ["study_project_id"], :name => "index_evaluations_on_study_project_id"
  add_index "evaluations", ["user_id"], :name => "index_evaluations_on_user_id"

  create_table "evaluators", :force => true do |t|
    t.string   "name"
    t.string   "home"
    t.text     "description"
    t.integer  "access_type"
    t.string   "url"
    t.integer  "user_id"
    t.boolean  "is_public",   :default => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
  end

  add_index "evaluators", ["user_id"], :name => "index_evaluators_on_user_id"

  create_table "jobs", :force => true do |t|
    t.integer  "project_id"
    t.integer  "delayed_job_id"
    t.integer  "num_items"
    t.integer  "num_dones"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.string   "name"
    t.datetime "begun_at"
    t.datetime "ended_at"
    t.datetime "registered_at"
  end

  add_index "jobs", ["delayed_job_id"], :name => "index_jobs_on_delayed_job_id"
  add_index "jobs", ["project_id"], :name => "index_jobs_on_project_id"

  create_table "messages", :force => true do |t|
    t.text     "body"
    t.integer  "job_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.string   "sourcedb"
    t.string   "sourceid"
    t.integer  "divid"
    t.text     "data"
  end

  add_index "messages", ["job_id"], :name => "index_messages_on_job_id"

  create_table "modifications", :force => true do |t|
    t.string   "hid"
    t.integer  "obj_id"
    t.string   "obj_type"
    t.string   "pred"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "modifications", ["obj_id"], :name => "index_modifications_on_obj_id"
  add_index "modifications", ["project_id"], :name => "index_modifications_on_project_id"

  create_table "news_notifications", :force => true do |t|
    t.string   "title"
    t.string   "category"
    t.string   "body"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "active",     :default => false
  end

  create_table "project_docs", :force => true do |t|
    t.integer "project_id"
    t.integer "doc_id"
    t.integer "denotations_num",   :default => 0
    t.integer "relations_num",     :default => 0
    t.integer "modifications_num", :default => 0
  end

  add_index "project_docs", ["denotations_num"], :name => "index_project_docs_on_denotations_num"
  add_index "project_docs", ["doc_id"], :name => "index_project_docs_on_doc_id"
  add_index "project_docs", ["project_id"], :name => "index_project_docs_on_project_id"

  create_table "projects", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "author"
    t.datetime "created_at",                                                          :null => false
    t.datetime "updated_at",                                                          :null => false
    t.string   "license"
    t.string   "reference"
    t.integer  "accessibility"
    t.integer  "status"
    t.integer  "user_id"
    t.string   "viewer"
    t.string   "rdfwriter"
    t.string   "xmlwriter"
    t.string   "bionlpwriter"
    t.string   "type"
    t.integer  "pmdocs_count",                     :default => 0
    t.integer  "pmcdocs_count",                    :default => 0
    t.integer  "denotations_num",                  :default => 0
    t.integer  "relations_num",                    :default => 0
    t.integer  "pending_associate_projects_count", :default => 0
    t.boolean  "annotations_zip_downloadable",     :default => true
    t.datetime "annotations_updated_at",           :default => '2016-04-08 06:25:21'
    t.text     "namespaces"
    t.integer  "process"
    t.integer  "annotations_count",                :default => 0
    t.string   "sample"
    t.boolean  "anonymize",                        :default => false,                 :null => false
    t.integer  "modifications_num",                :default => 0
    t.string   "textae_config"
    t.integer  "annotator_id"
  end

  add_index "projects", ["name"], :name => "index_projects_on_name", :unique => true

  create_table "queries", :force => true do |t|
    t.string   "title",      :default => ""
    t.text     "sparql",     :default => ""
    t.text     "comment"
    t.string   "show_mode"
    t.string   "projects"
    t.integer  "priority",   :default => 0,     :null => false
    t.boolean  "active",     :default => true,  :null => false
    t.integer  "project_id"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.integer  "category",   :default => 2
    t.boolean  "reasoning",  :default => false
  end

  add_index "queries", ["project_id"], :name => "index_queries_on_project_id"

  create_table "relations", :force => true do |t|
    t.string   "hid"
    t.integer  "subj_id"
    t.string   "subj_type"
    t.integer  "obj_id"
    t.string   "obj_type"
    t.string   "pred"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "relations", ["obj_id"], :name => "index_relations_on_obj_id"
  add_index "relations", ["project_id"], :name => "index_relations_on_project_id"
  add_index "relations", ["subj_id"], :name => "index_relations_on_subj_id"

  create_table "sequencers", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "home"
    t.integer  "user_id"
    t.string   "url"
    t.text     "parameters"
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.boolean  "is_public",   :default => false
  end

  add_index "sequencers", ["user_id"], :name => "index_sequencers_on_user_id"

  create_table "typesettings", :force => true do |t|
    t.integer  "doc_id"
    t.string   "style"
    t.integer  "begin"
    t.integer  "end"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",    :null => false
    t.string   "encrypted_password",     :default => "",    :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.text     "username",               :default => "",    :null => false
    t.boolean  "root",                   :default => false
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
  end

  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true
  add_index "users", ["username"], :name => "index_users_on_username", :unique => true

end
