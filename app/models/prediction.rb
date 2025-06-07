require 'rumale'
require 'rumale/ensemble'
require 'rumale/linear_model'
require 'rumale/model_selection'
require 'rumale/preprocessing'

class Prediction < ApplicationRecord
  validates :gender, presence: true, inclusion: { in: %w[male female] }
  validates :age,    presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than: 150 }
  validates :weight, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 500 }
  validates :height, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 250 }
  validates :prediction_probability, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :model_type, :model_version, presence: true
  validates :prediction_date, presence: true

  MODEL_PATH = Rails.root.join('training_data', 'rumale_trained_model.dump')

  def self.predict_dm!(attrs)
    # Load the trained model and its components
    model_data = Marshal.load(File.read(MODEL_PATH))
    model = model_data[:model]
    scaler = model_data[:scaler]
    selected_idx = model_data[:selected_idx]
    cat_values = model_data[:cat_values]
    feature_names = model_data[:feature_names]

    # Prepare features in the same order as training
    features = feature_names.map do |f|
      case f
      when 'Gender'
        val = attrs[:gender].to_s.strip.downcase
        cat_values['Gender'].index(val) || 0
      when 'Age'
        attrs[:age].to_f
      when 'Weight'
        attrs[:weight].to_f
      when 'Height'
        attrs[:height].to_f
      else
        0.0 # Default for any other features
      end
    end

    # Convert to Numo array and scale
    x = Numo::DFloat.cast([features])
    x_scaled = scaler.transform(x)
    
    # Select features
    x_selected = x_scaled[true, selected_idx]

    # Make prediction
    raw_label = model.predict(x_selected)
    prediction_proba = model.predict_proba(x_selected)[0, 1] # Get probability of positive class
    dm_flag = prediction_proba >= 0.9 # Using a 90% threshold for positive predictions

    # Get model details from the latest performance record
    latest_performance = ModelPerformance.latest.first

    # Persist the prediction with additional details
    create!(
      attrs.merge(
        dm_label: dm_flag,
        prediction_probability: prediction_proba,
        model_type: latest_performance&.model_type || 'Unknown',
        model_version: latest_performance&.model_version || 'v1.0',
        prediction_date: Time.current
      )
    )
  end

  def risk_level
    case prediction_probability
    when 0.0..0.3
      'Baixo'
    when 0.3..0.6
      'Médio'
    else
      'Alto'
    end
  end

  def formatted_probability
    "#{(prediction_probability * 100).round(1)}%"
  end
end
