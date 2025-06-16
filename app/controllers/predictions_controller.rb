class PredictionsController < ApplicationController
  # GET /predictions/new
  def new
    @prediction = Prediction.new
  end

  # GET /predictions
  def index
    @predictions = Prediction.all
  end

  # POST /predictions
  def create
    # Monta o hash inicial e calcula o BMI
    attrs = prediction_params.to_h.symbolize_keys
    height_m = attrs[:height].to_f / 100.0

    if height_m <= 0
      @prediction = Prediction.new
      flash.now[:alert] = "Altura deve ser maior que zero"
      return render :new, status: :unprocessable_entity
    end

    attrs[:bmi] = (attrs[:weight].to_f / (height_m**2)).round(1)

    # Prepara o objeto para a view
    @prediction = Prediction.new(attrs)

    begin
      # Chama o modelo Python
      prob = Ml::Predictor.risk(attrs.except(:height, :weight))
    rescue PyCall::PyError => e
      Rails.logger.error e.full_message
      flash.now[:alert] = "Erro interno ao calcular risco: #{e.message}"
      return render :new, status: :unprocessable_entity
    end

    @prediction.assign_attributes(
      prediction_probability:     prob,
      dm_label:        (prob >= 0.5),
      risk_level:      classify(prob),
      model_type:      "GBC",
      model_version:   "v1",
      prediction_date: Time.zone.now
    )

    if Prediction.table_exists? && @prediction.save
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
    else                "Alto"
    end
  end
end
