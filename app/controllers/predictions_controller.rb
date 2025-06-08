class PredictionsController < ApplicationController
  def new
    @prediction = Prediction.new
  end

  def index
    @predictions = Prediction.all
  end

  def create
    @prediction = Prediction.find_or_initialize_by(prediction_params)
    @prediction.dm_label = Prediction.predict_dm!(
      gender: params[:prediction][:gender],
      age: params[:prediction][:age],
      weight: params[:prediction][:weight],
      height: params[:prediction][:height]
    )

    # Set default values for required fields if not present
    @prediction.model_type ||= 'DefaultType'
    @prediction.model_version ||= 'v1.0'
    @prediction.prediction_date ||= Time.current

    if @prediction.save
      render :show
    else
      render :new
    end
  end

  private

  def prediction_params
    params.require(:prediction)
          .permit(:gender, :age, :weight, :height)
  end
end
