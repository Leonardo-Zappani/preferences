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

ActiveRecord::Schema[7.2].define(version: 2025_06_07_190725) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "model_performances", force: :cascade do |t|
    t.float "accuracy"
    t.float "precision"
    t.float "recall"
    t.float "f1_score"
    t.integer "total_predictions"
    t.integer "correct_predictions"
    t.string "model_version"
    t.datetime "training_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "predictions", force: :cascade do |t|
    t.decimal "height"
    t.decimal "weight"
    t.integer "prediction"
    t.decimal "metric_1"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gender"
    t.integer "age"
    t.boolean "dm_label"
  end
end
