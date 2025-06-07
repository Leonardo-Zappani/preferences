#!/usr/bin/env rails runner

require 'csv'
require 'liblinear'
require 'logger'
require 'benchmark'

logger       = Logger.new(STDOUT)
logger.level = Logger::INFO

csv_path   = Rails.root.join('training_data', 'training_data.csv')
model_path = Rails.root.join('training_data', 'svm_trained_model.model')

# 1) read & strip BOM
raw = File.read(csv_path)
raw.sub!("\xEF\xBB\xBF", "")

# 2) parse CSV into examples & labels
csv   = CSV.parse(raw, headers: true, col_sep: ';')
total = csv.size

examples = []
labels   = []

logger.info "Parsing #{total} rows…"
csv.each_with_index do |row, idx|
  gender_val = row['Gender'].strip.downcase == 'male' ? 1.0 : 0.0
  examples << [
    gender_val,
    row['Age'].to_f,
    row['Weight'].to_f,
    row['Height'].to_f
  ]
  labels << (row['DM_or_PreDM'].strip.upcase == 'TRUE' ? 1 : 0)

  if ((idx + 1) % (total / 10.0).ceil).zero? || idx + 1 == total
    pct = ((idx + 1) / total.to_f * 100).round(1)
    logger.info "Parsed #{idx+1}/#{total} (#{pct}%)"
  end
end

# 3) set up LIBLINEAR parameters
opts = {
  solver_type: Liblinear::L2R_L2LOSS_SVC_DUAL,  # linear SVM
  cost:        100.0,                           # C parameter
  epsilon:     1e-5                             # stopping criterion
}

# 4) train final model & time it
logger.info "Training linear model on all #{total} instances…"
train_time = Benchmark.measure do
  @model = Liblinear.train(opts, labels, examples)
end
logger.info "⏱ Training took #{train_time.real.round(3)}s"

@model.save(model_path.to_s)
logger.info "✓ Model saved to #{model_path}"

# 5) k-fold cross-validation via LIBLINEAR's built-in
nfold = 10
logger.info "Starting #{nfold}-fold cross-validation…"
cv_time = Benchmark.measure do
  results = Liblinear.cross_validation(nfold, opts, labels, examples)
  
  # Calculate metrics
  correct = results.each_with_index.count { |pred, i| pred == labels[i] }
  accuracy = correct.to_f / total
  
  # Calculate precision, recall, and F1 score
  true_positives = results.each_with_index.count { |pred, i| pred == 1 && labels[i] == 1 }
  false_positives = results.each_with_index.count { |pred, i| pred == 1 && labels[i] == 0 }
  false_negatives = results.each_with_index.count { |pred, i| pred == 0 && labels[i] == 1 }
  
  precision = true_positives.to_f / (true_positives + false_positives)
  recall = true_positives.to_f / (true_positives + false_negatives)
  f1_score = 2 * (precision * recall) / (precision + recall)
  
  # Log metrics
  logger.info "🏁 #{nfold}-fold CV metrics:"
  logger.info "   Accuracy:  #{'%.2f' % (accuracy * 100)}%"
  logger.info "   Precision: #{'%.2f' % (precision * 100)}%"
  logger.info "   Recall:    #{'%.2f' % (recall * 100)}%"
  logger.info "   F1 Score:  #{'%.2f' % (f1_score * 100)}%"
  
  # Save performance metrics
  model_version = File.read(Rails.root.join('training_data', 'model_version.txt')).strip rescue '1.0'
  ModelPerformance.create!(
    accuracy: accuracy,
    precision: precision,
    recall: recall,
    f1_score: f1_score,
    total_predictions: total,
    correct_predictions: correct,
    model_version: model_version,
    training_date: Time.current
  )
  logger.info "✓ Performance metrics saved to database"
end
logger.info "⏱ CV took #{cv_time.real.round(3)}s"
