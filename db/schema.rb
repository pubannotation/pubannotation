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

ActiveRecord::Schema.define(:version => 20120927031610) do

  create_table "annsets", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "annotator"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "annsets", ["name"], :name => "index_annsets_on_name", :unique => true

  create_table "catanns", :force => true do |t|
    t.string   "hid"
    t.integer  "doc_id"
    t.integer  "begin"
    t.integer  "end"
    t.string   "category"
    t.integer  "annset_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "catanns", ["annset_id"], :name => "index_catanns_on_annset_id"
  add_index "catanns", ["doc_id"], :name => "index_catanns_on_doc_id"

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

  add_index "docs", ["sourceid"], :name => "index_docs_on_sourceid", :unique => true

  create_table "insanns", :force => true do |t|
    t.string   "hid"
    t.integer  "type_id"
    t.string   "type_type"
    t.integer  "annset_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "insanns", ["annset_id"], :name => "index_insanns_on_annset_id"
  add_index "insanns", ["type_id"], :name => "index_insanns_on_type_id"

  create_table "relanns", :force => true do |t|
    t.string   "hid"
    t.integer  "subject_id"
    t.string   "subject_type"
    t.integer  "object_id"
    t.string   "object_type"
    t.string   "relation"
    t.integer  "annset_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  add_index "relanns", ["annset_id"], :name => "index_relanns_on_annset_id"
  add_index "relanns", ["object_id"], :name => "index_relanns_on_object_id"
  add_index "relanns", ["subject_id"], :name => "index_relanns_on_subject_id"

end
