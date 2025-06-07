class ModelPerformance < ApplicationRecord
  validates :accuracy, :precision, :recall, :f1_score, 
            :total_predictions, :correct_predictions, :model_version, 
            :training_date, presence: true
  validates :accuracy, :precision, :recall, :f1_score, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :total_predictions, :correct_predictions, 
            numericality: { greater_than_or_equal_to: 0 }

  scope :latest, -> { order(training_date: :desc) }
  scope :by_version, ->(version) { where(model_version: version) }
  scope :recent, -> { where('training_date >= ?', 30.days.ago) }

  def error_rate
    1 - accuracy
  end

  def prediction_rate
    return 0 if total_predictions.zero?
    (correct_predictions.to_f / total_predictions * 100).round(2)
  end
end
