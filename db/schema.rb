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

ActiveRecord::Schema[8.0].define(version: 2025_06_25_191530) do
  create_table "audit_members", force: :cascade do |t|
    t.integer "audit_session_id", null: false
    t.integer "team_member_id", null: false
    t.boolean "access_validated"
    t.boolean "removed"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_session_id", "team_member_id"], name: "index_audit_members_on_session_and_member", unique: true
    t.index ["audit_session_id"], name: "index_audit_members_on_audit_session_id"
    t.index ["team_member_id"], name: "index_audit_members_on_team_member_id"
  end

  create_table "audit_notes", force: :cascade do |t|
    t.integer "audit_member_id", null: false
    t.integer "user_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_member_id"], name: "index_audit_notes_on_audit_member_id"
    t.index ["user_id"], name: "index_audit_notes_on_user_id"
  end

  create_table "audit_sessions", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "user_id", null: false
    t.integer "team_id", null: false
    t.string "name"
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.date "due_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_audit_sessions_on_organization_id"
    t.index ["team_id"], name: "index_audit_sessions_on_team_id"
    t.index ["user_id"], name: "index_audit_sessions_on_user_id"
  end

  create_table "issue_correlations", force: :cascade do |t|
    t.integer "team_member_id", null: false
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.string "title"
    t.text "description"
    t.string "status", default: "open"
    t.datetime "resolved_at"
    t.datetime "issue_created_at"
    t.datetime "issue_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_member_id", "github_issue_number"], name: "index_issue_correlations_on_member_and_issue", unique: true
    t.index ["team_member_id"], name: "index_issue_correlations_on_team_member_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "github_login"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "team_members", force: :cascade do |t|
    t.integer "team_id", null: false
    t.string "github_login"
    t.string "name"
    t.string "avatar_url"
    t.boolean "maintainer_role"
    t.boolean "government_employee"
    t.boolean "active", default: true, null: false
    t.datetime "last_seen_at"
    t.datetime "first_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "github_login"], name: "index_team_members_on_team_id_and_github_login", unique: true
    t.index ["team_id"], name: "index_team_members_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "name"
    t.string "github_slug"
    t.text "description"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "search_terms"
    t.text "exclusion_terms"
    t.string "search_repository"
    t.index ["organization_id"], name: "index_teams_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address"
    t.string "password_digest"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "audit_members", "audit_sessions"
  add_foreign_key "audit_members", "team_members"
  add_foreign_key "audit_notes", "audit_members"
  add_foreign_key "audit_notes", "users"
  add_foreign_key "audit_sessions", "organizations"
  add_foreign_key "audit_sessions", "teams"
  add_foreign_key "audit_sessions", "users"
  add_foreign_key "issue_correlations", "team_members"
  add_foreign_key "sessions", "users"
  add_foreign_key "team_members", "teams"
  add_foreign_key "teams", "organizations"
end
