# app/services/ml/predictor.rb
require 'pycall/import'

module Ml
  class Predictor
    extend PyCall::Import

    MODEL_PATH = Rails.root.join('storage', 'models', 'gbc_final.joblib').to_s

    # import once at the top
    pyimport 'joblib',  as: :jl
    pyimport 'pandas', as: :pd

    PIPELINE     = jl.load(MODEL_PATH)
    PREPROCESSOR = PIPELINE.named_steps['pre']
    CLASSIFIER   = PIPELINE.named_steps['clf']

    # turn the instance method into a module‐function if you like,
    # but you can also just call Predictor.risk
    def self.risk(attrs)
      # 1) Build a 1-row DataFrame with string keys
      raw = attrs.transform_keys(&:to_s)
      df  = pd.DataFrame.new([raw])

      # 2) Preprocess
      xt = PREPROCESSOR.transform(df)

      # 3) Predict
      proba = CLASSIFIER.predict_proba(xt)[0, 1]
      proba.to_f
    rescue PyCall::PyError => e
      Rails.logger.error("[Ml::Predictor] PyCall failed: #{e.class} #{e.message}")
      nil
    end
  end
end
