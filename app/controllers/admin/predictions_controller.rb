class Admin::PredictionsController < ApplicationController
  def index
    @oredictions = Prediction.all
  end
end
