# app/services/ml/predictor.rb
require "pycall/import"
include PyCall::Import

module Ml
  class Predictor
    PY_DIR = Rails.root.join("python").to_s
    SYS    = PyCall.import_module("sys")

    # instead of SYS.path.unshift(PY_DIR)
    SYS.path.insert(0, PY_DIR) unless SYS.path.include?(PY_DIR)

    PD        = PyCall.import_module("pandas")
    JOBLIB    = PyCall.import_module("joblib")
    # …

    MODEL_PATH   = Rails.root.join("storage","models","gbm_optuna.joblib").to_s
    METRICS_PATH = Rails.root.join("storage","models","metrics.json").to_s

    COLS = %w[
      age bmi HbA1c_level blood_glucose_level
      gender smoking_history hypertension heart_disease
      age_bmi bmi_cat risk_count
    ]

    def self.risk(raw)
      # normalize / cast…
      features = raw.transform_keys(&:to_s)
      features["age"]                 = features["age"].to_i
      features["bmi"]                 = features["bmi"].to_f
      features["HbA1c_level"]         = features["HbA1c_level"].to_f
      features["blood_glucose_level"] = features["blood_glucose_level"].to_f
      features["hypertension"]        = features["hypertension"].to_i
      features["heart_disease"]       = features["heart_disease"].to_i
      # leave gender and smoking_history as strings…

      # derived
      features["age_bmi"] = features["age"] * features["bmi"]
      features["bmi_cat"] = case features["bmi"]
                            when ..18.5 then "under"
                            when ..25   then "normal"
                            when ..30   then "over"
                            else             "obese"
                            end
      features["risk_count"] =
        features["hypertension"] +
        features["heart_disease"] +
        (features["smoking_history"] != "never" ? 1 : 0)

      # build DataFrame
      df = PD.DataFrame.new([features], columns: COLS)

      # load model & threshold
      pipe    = JOBLIB.load(MODEL_PATH)
      metrics = JSON.parse(File.read(METRICS_PATH))
      thr     = metrics["best_threshold"]

      # predict
      proba    = pipe.predict_proba(df)[0][1].to_f
      positive = proba >= thr

      { probability: proba, positive: positive }
    rescue PyCall::PyError => e
      Rails.logger.error("[Ml::Predictor] PyError: #{e.message}")
      raise PredictionError, "Erro ao gerar predição. Tente novamente."
    end
  end
end
