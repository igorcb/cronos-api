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

ActiveRecord::Schema[7.0].define(version: 2023_10_04_224336) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "softwares", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "idx_softwares_on_company_id_and_name_uniq", unique: true
    t.index ["company_id"], name: "index_softwares_on_company_id"
  end

  create_table "task_items", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.date "date_start", null: false
    t.time "hour_start", null: false
    t.date "date_end"
    t.time "hour_end"
    t.integer "status", null: false
    t.text "observation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_task_items_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "software_id", null: false
    t.string "code"
    t.string "name"
    t.text "description"
    t.date "date_opened"
    t.integer "status"
    t.date "date_delivered"
    t.text "observation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "software_id", "code"], name: "idx_card_on_company_id_and_software_and_code_uniq", unique: true
    t.index ["company_id"], name: "index_tasks_on_company_id"
    t.index ["software_id"], name: "index_tasks_on_software_id"
  end

  add_foreign_key "softwares", "companies"
  add_foreign_key "task_items", "tasks"
  add_foreign_key "tasks", "companies"
  add_foreign_key "tasks", "softwares"
end
