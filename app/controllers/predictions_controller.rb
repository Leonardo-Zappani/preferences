# app/controllers/predictions_controller.rb

class PredictionsController < ApplicationController
  # GET /predictions/new
  def new
    @prediction = Prediction.new
  end

  # GET /predictions
  def index
    @predictions = Prediction.all
  end

  # GET /predictions/:id
  def show
    @prediction = Prediction.find(params[:id])
  end

  # POST /predictions/process_pdf
  def process_pdf
    unless params[:pdf_file].present?
      return render json: { error: 'Nenhum arquivo PDF foi enviado' }, status: :bad_request
    end

    begin
      file_content = params[:pdf_file].read
      prediction = PdfOcrMapper.new(file_content).call

      render json: {
        success: true,
        prediction_id: prediction.id,
        redirect_url: prediction_path(prediction)
      }, status: :ok
    rescue PdfOcrMapper::ExtractionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("[PredictionsController#process_pdf] #{e.class}: #{e.message}")
      render json: { error: 'Erro interno ao processar o PDF. Tente novamente.' }, status: :internal_server_error
    end
  end

  # POST /predictions
  def create
    attrs = prediction_params.to_h.symbolize_keys
    height_m = attrs[:height].to_f / 100.0

    if height_m <= 0
      @prediction = Prediction.new
      return render :new, status: :unprocessable_entity
    end

    attrs[:bmi] = (attrs[:weight].to_f / (height_m**2)).round(1)
    @prediction = Prediction.predict!(attrs)

    if @prediction.save
      render :show

    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def prediction_params
    params.require(:prediction).permit(
      :gender, :age, :height, :weight,
      :HbA1c_level, :blood_glucose_level,
      :hypertension, :heart_disease, :smoking_history
    )
  end

  def classify(prob)
    case prob
    when 0.0...0.33 then "Baixo"
    when 0.33...0.66 then "Médio"
    else "Alto"
    end
  end
end
