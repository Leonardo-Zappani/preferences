class Prediction < ApplicationRecord
  enum gender:          { male: 'male', female: 'female' }
  enum smoking_history: { never: 'never', former: 'former', current: 'current' }

  before_validation :compute_bmi, if: -> { height && weight && bmi.nil? }

  validates :gender, :smoking_history, presence: true
  validates :age, numericality: { only_integer: true, greater_than: 0, less_than: 150 }
  validates :height, :weight, :bmi,
            numericality: { greater_than: 0 }
  validates :HbA1c_level, :blood_glucose_level,
            numericality: { greater_than_or_equal_to: 0 }
  validates :hypertension, :heart_disease,
            inclusion: { in: [0, 1] }
  validates :prediction_probability,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :dm_label, inclusion: { in: [true, false] }
  validates :risk_level, inclusion: { in: %w[Baixo Médio Alto] }
  validates :model_type, :model_version, :prediction_date, presence: true

  def self.predict!(attrs)
    clean = attrs.transform_keys(&:to_sym)
    p = new(clean)

    begin
      prob = Ml::Predictor.risk(
        age:                 p.age,
        bmi:                 p.bmi,
        HbA1c_level:         p.HbA1c_level,
        blood_glucose_level: p.blood_glucose_level,
        gender:              p.gender,
        smoking_history:     p.smoking_history,
        hypertension:        p.hypertension,
        heart_disease:       p.heart_disease
      )

      p.prediction_probability = prob
      p.dm_label               = (prob >= 0.5)
      p.risk_level             = p.classify(prob)
      p.model_type             = "GradientBoostingClassifier"
      p.model_version          = "final"
      p.prediction_date        = Time.current

      p.save!
      p
    rescue MemoryError => e
      Rails.logger.error("Memory error during prediction: #{e.message}")
      raise PredictionError, "The prediction could not be completed due to memory constraints. Please try again with a smaller dataset or contact support."
    rescue StandardError => e
      Rails.logger.error("Error during prediction: #{e.message}")
      raise PredictionError, "An error occurred during prediction. Please try again or contact support."
    end
  end

  def formatted_probability
    "#{(prediction_probability * 100).round(1)}%"
  end

  private

  def compute_bmi
    m = height.to_f / 100.0
    self.bmi = (weight.to_f / (m**2)).round(1) if m.positive?
  end

  def self.classify(prob)
    case prob
    when 0.0...0.33 then 'Baixo'
    when 0.33...0.66 then 'Médio'
    else                'Alto'
    end
  end
end
