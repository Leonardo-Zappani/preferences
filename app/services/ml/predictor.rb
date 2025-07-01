require "pycall"

module Ml
  class Predictor
    PD     = PyCall.import_module("pandas")
    JOBLIB = PyCall.import_module("joblib")
    SYS    = PyCall.import_module("sys")
    IMPORTLIB = PyCall.import_module("importlib")

    PY_DIR = Rails.root.join("python").to_s
    SYS.path.insert(0, PY_DIR) unless SYS.path.include?(PY_DIR)

    # importa o threshold (já não precisamos do DataFrameTransformer!)
    IMPORTLIB.import_module("threshold_classifier")

    MODEL_PATH = Rails.root.join("storage","models","gbm_optuna.joblib").to_s
    PIPE = JOBLIB.load(MODEL_PATH)

    FEATURE_KEYS = %w[
      age bmi HbA1c_level blood_glucose_level
      gender smoking_history hypertension heart_disease
    ].freeze

    DERIVED_KEYS = %w[age_bmi bmi_cat risk_count].freeze
    ALL_KEYS     = FEATURE_KEYS + DERIVED_KEYS

    def self.risk(raw)
      # 1) extrai e converte só as 8 features originais
      f = {
        "age"                 => raw["age"].to_i,
        "bmi"                 => raw["bmi"].to_f,
        "HbA1c_level"         => raw["HbA1c_level"].to_f,
        "blood_glucose_level" => raw["blood_glucose_level"].to_f,
        "gender"              => raw["gender"],         # "male"/"female"
        "smoking_history"     => raw["smoking_history"],# e.g. "never"
        "hypertension"        => raw["hypertension"].to_i,
        "heart_disease"       => raw["heart_disease"].to_i,
      }

      # 2) gera as 3 features extras
      f["age_bmi"]    = f["age"] * f["bmi"]
      f["bmi_cat"]    = case f["bmi"]
                        when ..18.5 then "under"
                        when ..25   then "normal"
                        when ..30   then "over"
                        else             "obese"
                        end
      f["risk_count"] = f["hypertension"] +
                        f["heart_disease"] +
                        (f["smoking_history"] != "never" ? 1 : 0)

      # 3) monta DataFrame com as 11 colunas que o pipeline espera
      df = PD.DataFrame.new([f], columns: ALL_KEYS)

      # 4) chama o pipeline
      proba    = PIPE.predict_proba(df)[0][1].to_f
      positive = PIPE.predict(df)[0] == 1

      { probability: proba, positive: positive }
    rescue PyCall::PyError => e
      Rails.logger.error("[Ml::Predictor] PyCall Error: #{e.class} – #{e.message}")
      raise PredictionError, "Erro ao gerar predição. Tente novamente."
    end
  end
end
