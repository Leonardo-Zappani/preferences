class PredictionsController < ApplicationController
  def new
    @prediction = Prediction.new
  end

  def create
    @prediction = Prediction.find_or_initialize_by(prediction_params)
    @prediction.dm_label = Prediction.predict_dm!(
      gender: params[:prediction][:gender],
      age: params[:prediction][:age],
      weight: params[:prediction][:weight],
      height: params[:prediction][:height]
    )

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
