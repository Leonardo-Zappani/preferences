class DashboardController < ApplicationController
  def index
    @latest_performance = ModelPerformance.latest.first
    @recent_performances = ModelPerformance.recent.order(training_date: :asc)
    
    @metrics = {
      accuracy: @recent_performances.pluck(:accuracy),
      precision: @recent_performances.pluck(:precision),
      recall: @recent_performances.pluck(:recall),
      f1_score: @recent_performances.pluck(:f1_score),
      dates: @recent_performances.pluck(:training_date).map { |date| date.strftime("%Y-%m-%d") }
    }

    @total_predictions = ModelPerformance.sum(:total_predictions)
    @total_correct = ModelPerformance.sum(:correct_predictions)
    @average_accuracy = ModelPerformance.average(:accuracy)&.round(4) || 0
    @model_versions = ModelPerformance.distinct.pluck(:model_version)
  end
end
