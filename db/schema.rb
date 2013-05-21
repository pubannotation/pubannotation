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

ActiveRecord::Schema.define(:version => 20130521075634) do

  create_table "docs", :force => true do |t|
    t.text     "body"
    t.string   "source"
    t.string   "sourcedb"
    t.string   "sourceid"
    t.integer  "serial"
    t.string   "section"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "docs", ["serial"], :name => "index_docs_on_serial"
  add_index "docs", ["sourcedb"], :name => "index_docs_on_sourcedb"
  add_index "docs", ["sourceid"], :name => "index_docs_on_sourceid"

  create_table "docs_projects", :id => false, :force => true do |t|
    t.integer "project_id"
    t.integer "doc_id"
  end

  add_index "docs_projects", ["project_id", "doc_id"], :name => "index_docs_projects_on_project_id_and_doc_id", :unique => true

  create_table "insanns", :force => true do |t|
    t.string   "hid"
    t.integer  "insobj_id"
    t.string   "instype"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "insanns", ["insobj_id"], :name => "index_insanns_on_insobj_id"
  add_index "insanns", ["project_id"], :name => "index_insanns_on_project_id"

  create_table "modanns", :force => true do |t|
    t.string   "hid"
    t.integer  "modobj_id"
    t.string   "modobj_type"
    t.string   "modtype"
    t.integer  "project_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "modanns", ["modobj_id"], :name => "index_modanns_on_modobj_id"
  add_index "modanns", ["project_id"], :name => "index_modanns_on_project_id"

  create_table "projects", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "author"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.string   "license"
    t.string   "reference"
    t.string   "editor"
    t.integer  "accessibility"
    t.integer  "status"
    t.integer  "user_id"
    t.string   "viewer"
    t.string   "rdfwriter"
    t.string   "xmlwriter"
    t.string   "bionlpwriter"
  end

  add_index "projects", ["name"], :name => "index_annsets_on_name", :unique => true
  add_index "projects", ["name"], :name => "index_projects_on_name", :unique => true

  create_table "relanns", :force => true do |t|
    t.string   "hid"
    t.integer  "relsub_id"
    t.string   "relsub_type"
    t.integer  "relobj_id"
    t.string   "relobj_type"
    t.string   "reltype"
    t.integer  "project_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "relanns", ["project_id"], :name => "index_relanns_on_project_id"
  add_index "relanns", ["relobj_id"], :name => "index_relanns_on_relobj_id"
  add_index "relanns", ["relsub_id"], :name => "index_relanns_on_relsub_id"

  create_table "spans", :force => true do |t|
    t.string   "hid"
    t.integer  "doc_id"
    t.integer  "begin"
    t.integer  "end"
    t.string   "category"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "spans", ["doc_id"], :name => "index_spans_on_doc_id"
  add_index "spans", ["project_id"], :name => "index_spans_on_project_id"

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "", :null => false
    t.string   "encrypted_password",     :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.string   "username"
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
