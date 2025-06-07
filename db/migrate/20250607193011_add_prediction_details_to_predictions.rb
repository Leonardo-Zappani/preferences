class AddPredictionDetailsToPredictions < ActiveRecord::Migration[7.0]
  def change
    add_column :predictions, :prediction_probability, :float, null: false, default: 0.0
    add_column :predictions, :model_type, :string, null: false, default: 'Unknown'
    add_column :predictions, :model_version, :string, null: false, default: 'v1.0'
    add_column :predictions, :prediction_date, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    
    # Remove defaults after adding columns
    change_column_default :predictions, :model_type, from: 'Unknown', to: nil
    change_column_default :predictions, :model_version, from: 'v1.0', to: nil
    
    add_index :predictions, :prediction_date
    add_index :predictions, :model_version
  end
end
