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

ActiveRecord::Schema.define(:version => 20121018141253) do

  create_table "annsets", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "author"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "license"
    t.string   "uploader"
    t.string   "reference"
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

  add_index "docs", ["serial"], :name => "index_docs_on_serial"
  add_index "docs", ["sourcedb"], :name => "index_docs_on_sourcedb"
  add_index "docs", ["sourceid"], :name => "index_docs_on_sourceid"

  create_table "insanns", :force => true do |t|
    t.string   "hid"
    t.integer  "insobj_id"
    t.string   "instype"
    t.integer  "annset_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "insanns", ["annset_id"], :name => "index_insanns_on_annset_id"
  add_index "insanns", ["insobj_id"], :name => "index_insanns_on_insobj_id"

  create_table "modanns", :force => true do |t|
    t.string   "hid"
    t.integer  "modobj_id"
    t.string   "modobj_type"
    t.string   "modtype"
    t.integer  "annset_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "modanns", ["annset_id"], :name => "index_modanns_on_annset_id"
  add_index "modanns", ["modobj_id"], :name => "index_modanns_on_modobj_id"

  create_table "relanns", :force => true do |t|
    t.string   "hid"
    t.integer  "relsub_id"
    t.string   "relsub_type"
    t.integer  "relobj_id"
    t.string   "relobj_type"
    t.string   "reltype"
    t.integer  "annset_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "relanns", ["annset_id"], :name => "index_relanns_on_annset_id"
  add_index "relanns", ["relobj_id"], :name => "index_relanns_on_relobj_id"
  add_index "relanns", ["relsub_id"], :name => "index_relanns_on_relsub_id"

end
