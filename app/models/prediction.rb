# app/models/prediction.rb
require 'liblinear'   # ← add this

class Prediction < ApplicationRecord
  validates :gender, presence: true, inclusion: { in: %w[male female] }
  validates :age,    presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than: 150 }
  validates :weight, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 500 }
  validates :height, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 250 }

  MODEL_PATH = Rails.root.join('training_data','svm_trained_model.model').to_s

  def self.predict_dm!(attrs)
    # 1) feature vector
    fv = [
      attrs[:gender].to_s.strip.downcase == 'male' ? 1.0 : 0.0,
      attrs[:age].to_f,
      attrs[:weight].to_f,
      attrs[:height].to_f
    ]

    # 2) load & predict
    model     = ::Liblinear::Model.load(MODEL_PATH)
    raw_label = ::Liblinear.predict(model, fv)
    dm_flag   = (raw_label == 1)

    # 3) persist
    create!(attrs.merge(dm_label: dm_flag))
  end
end
