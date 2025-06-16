# app/services/ml/predictor.rb
module Ml
  module Predictor
    extend self
    include PyCall::Import

    MODEL_PATH    = Rails.root.join("storage","models","gbc_final.joblib").to_s
    pyimport 'joblib', as: :jl
    PIPELINE      = jl.load(MODEL_PATH)

    # break out the steps
    PREPROCESSOR = PIPELINE.named_steps['pre']
    CLASSIFIER   = PIPELINE.named_steps['clf']

    def risk(attrs)
      pyimport 'pandas', as: :pd

      # 1) Build a 1-row DataFrame with string keys
      raw = attrs.transform_keys(&:to_s)
      df  = pd.DataFrame.new([ raw ])

      # 2) Run just the column transformer
      xt = PREPROCESSOR.transform(df)

      # 3) Classify
      proba = CLASSIFIER.predict_proba(xt)[0,1]
      proba.to_f
    end
  end
end
