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
    encoder = model_data[:encoder]
    selected_idx = model_data[:selected_idx]
    feature_names = model_data[:feature_names]

    # Prepare features in the same order as training
    features = feature_names.map do |f|
      case f
      when 'Gender'
        # One-hot encode gender
        attrs[:gender].to_s.strip.downcase == 'male' ? 1.0 : 0.0
      when 'Age', 'Weight', 'Height'
        attrs[f.downcase.to_sym].to_f
      else
        0.0 # Default for any other features
      end
    end

    # Convert to Numo array
    x = Numo::DFloat.cast([features])
    
    # Apply preprocessing steps in the same order as training
    x_encoded = encoder.transform(x)
    x_scaled = scaler.transform(x_encoded)
    x_selected = x_scaled[true, selected_idx]

    # Make prediction
    prediction_proba = model.predict_proba(x_selected)[0, 1] # Get probability of positive class
    
    # Get model details from the latest performance record
    latest_performance = ModelPerformance.latest.first

    # Persist the prediction with additional details
    create!(
      attrs.merge(
        dm_label: prediction_proba >= 0.5, # Use 0.5 threshold for binary prediction
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
