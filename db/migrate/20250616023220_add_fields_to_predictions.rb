class AddFieldsToPredictions < ActiveRecord::Migration[7.2]
  def change
    change_table :predictions do |t|
      t.float    :bmi
      t.float    :HbA1c_level
      t.float    :blood_glucose_level
      t.string   :smoking_history
      t.integer  :hypertension
      t.integer  :heart_disease
      t.string   :risk_level
    end
  end
end
