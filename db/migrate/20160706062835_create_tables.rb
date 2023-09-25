class CreateTables < ActiveRecord::Migration[4.2]
  if ActiveRecord::Base.connection.table_exists?('associate_projects_projects')
    drop_table :associate_projects_projects
  end

  unless ActiveRecord::Base.connection.table_exists?('annotators')
    create_table "annotators" do |t|
      t.string   "abbrev"
      t.string   "name"
      t.text     "description"
      t.string   "home"
      t.integer  "user_id"
      t.string   "url"
      t.text     "params"
      t.integer  "method"
      t.string   "url2"
      t.text     "params2"
      t.integer  "method2"
      t.datetime "created_at",  :null => false
      t.datetime "updated_at",  :null => false
    end
  end

  unless Annotator.connection.index_exists?(:annotators, :abbrev)
    add_index :annotators, :abbrev, unique: :true
  end

  unless Annotator.connection.index_exists?(:annotators, :user_id)
    add_index "annotators", ["user_id"], :name => "index_annotators_on_user_id"
  end

  unless ActiveRecord::Base.connection.table_exists?('associate_maintainers')
    create_table "associate_maintainers" do |t|
      t.integer  "user_id"
      t.integer  "project_id"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  end

  unless AssociateMaintainer.connection.index_exists?(:associate_maintainers, :project_id)
    add_index :associate_maintainers, :project_id
  end

  unless AssociateMaintainer.connection.index_exists?(:associate_maintainers, :user_id)
    add_index :associate_maintainers, :user_id
  end

  unless ActiveRecord::Base.connection.table_exists?('delayed_jobs')
    create_table "delayed_jobs" do |t|
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
  end

  unless ActiveRecord::Base.connection.execute("SELECT * FROM pg_indexes WHERE indexname= 'delayed_jobs_priority'").cmd_tuples == 1
    add_index :delayed_jobs, [:priority, :run_at]
  end

  unless ActiveRecord::Base.connection.table_exists?('denotations')
    create_table "denotations" do |t|
      t.string   "hid"
      t.integer  "doc_id"
      t.integer  "begin"
      t.integer  "end"
      t.string   "obj"
      t.integer  "project_id"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  end

  unless Denotation.connection.index_exists?(:denotations, :doc_id)
    add_index :denotations, :doc_id
  end

  unless Denotation.connection.index_exists?(:denotations, :project_id)
    add_index :denotations, :project_id
  end

  unless ActiveRecord::Base.connection.table_exists?('docs')
    create_table "docs" do |t|
      t.text     "body"
      t.string   "source"
      t.string   "sourcedb"
      t.string   "sourceid"
      t.integer  "serial"
      t.string   "section"
      t.datetime "created_at",                          :null => false
      t.datetime "updated_at",                          :null => false
      t.integer  "denotations_count", :default => 0
      t.integer  "subcatrels_count",  :default => 0
      t.boolean  "delta",             :default => true, :null => false
      t.integer  "projects_count",    :default => 0
    end
  end

  unless Doc.connection.index_exists?(:docs, :projects_count)
    add_index :docs, :projects_count
  end

  unless Doc.connection.index_exists?(:docs, :serial)
    add_index :docs, :serial
  end

  unless Doc.connection.index_exists?(:docs, :sourcedb)
    add_index :docs, :sourcedb
  end

  unless Doc.connection.index_exists?(:docs, :sourceid)
    add_index :docs, :sourceid
  end

  unless ActiveRecord::Base.connection.table_exists?('docs_projects')
    create_table "docs_projects", :id => false do |t|
      t.integer "project_id"
      t.integer "doc_id"
    end
  end

  unless ActiveRecord::Base.connection.table_exists?('jobs')
    create_table "jobs" do |t|
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
  end

  unless Job.connection.index_exists?(:jobs, :delayed_job_id)
    add_index :jobs, :delayed_job_id
  end

  unless Job.connection.index_exists?(:jobs, :project_id)
    add_index :jobs, :project_id
  end

  unless ActiveRecord::Base.connection.table_exists?('messages')
    create_table "messages" do |t|
      t.text     "body"
      t.integer  "job_id"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
      t.string   "sourcedb"
      t.string   "sourceid"
      t.integer  "divid"
    end
  end

  unless Message.connection.index_exists?(:messages, :job_id)
    add_index :messages, :job_id
  end

  unless ActiveRecord::Base.connection.table_exists?('modifications')
    create_table "modifications" do |t|
      t.string   "hid"
      t.integer  "obj_id"
      t.string   "obj_type"
      t.string   "pred"
      t.integer  "project_id"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  end

  unless Modification.connection.index_exists?(:modifications, :obj_id)
    add_index :modifications, :obj_id
  end

  unless Modification.connection.index_exists?(:modifications, :project_id)
    add_index :modifications, :project_id
  end

  unless ActiveRecord::Base.connection.table_exists?('projects')
    create_table "projects" do |t|
      t.string   "name"
      t.text     "description"
      t.string   "author"
      t.datetime "created_at",                                                          :null => false
      t.datetime "updated_at",                                                          :null => false
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
      t.string   "type"
      t.integer  "pmdocs_count",                     :default => 0
      t.integer  "pmcdocs_count",                    :default => 0
      t.integer  "denotations_count",                :default => 0
      t.integer  "relations_count",                  :default => 0
      t.integer  "pending_associate_projects_count", :default => 0
      t.boolean  "annotations_zip_downloadable",     :default => true
      t.datetime "annotations_updated_at",           :default => '2016-04-08 06:25:21'
      t.text     "namespaces"
      t.integer  "process"
      t.integer  "annotations_count",                :default => 0
      t.string   "sample"
      t.boolean  "anonymize",                        :default => false,                 :null => false
    end
  end

  unless Project.connection.index_exists?(:projects, :name)
    # add_index "projects", ["name"], :name => "index_annsets_on_name", :unique => true
    add_index :projects, :name, unique: :true
  end

  unless ActiveRecord::Base.connection.table_exists?('relations')
    create_table "relations" do |t|
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
  end

  unless Relation.connection.index_exists?(:relations, :obj_id)
    add_index :relations, :obj_id
  end

  unless Relation.connection.index_exists?(:relations, :project_id)
    add_index :relations, :project_id
  end

  unless Relation.connection.index_exists?(:relations, :subj_id)
    add_index :relations, :subj_id
  end

  unless ActiveRecord::Base.connection.table_exists?('users')
    create_table "users" do |t|
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
    end
  end

  unless User.connection.index_exists?(:users, :email)
    add_index :users, :email, unique: true
  end

  unless User.connection.index_exists?(:users, :reset_password_token)
    add_index :users, :reset_password_token, unique: :true
  end

  unless User.connection.index_exists?(:users, :username)
    add_index :users, :username, unique: true
  end
end
