require 'json'

METRICS_PATH = Rails.root.join('storage', 'models', 'metrics.json')

unless File.exist?(METRICS_PATH)
  raise "Arquivo de métricas não encontrado: #{METRICS_PATH}"
end

metrics = JSON.parse(File.read(METRICS_PATH))

# Calcular campos adicionais
total_predictions = metrics["total_predictions"]
correct_predictions = metrics["correct_predictions"]
f1_score = metrics["f1_score"]
model_version = "gbm_v1"  # substitua pela versão atual do modelo
training_date = Time.current

ModelPerformance.create!(
  accuracy: metrics["accuracy"],
  precision: metrics["precision"],
  recall: metrics["recall"],
  f1_score: f1_score,
  total_predictions: total_predictions,
  correct_predictions: correct_predictions,
  model_version: model_version,
  training_date: training_date
)

puts "✅  Métricas inseridas com sucesso no banco de dados!"
