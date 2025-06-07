#!/usr/bin/env rails runner

require 'csv'
require 'rumale'
require 'logger'
require 'benchmark'
require 'json'

logger       = Logger.new(STDOUT)
logger.level = Logger::INFO

csv_path   = Rails.root.join('training_data', 'training_data.csv')
model_path = Rails.root.join('training_data', 'rumale_trained_model.dump')

# Constants
TEST_SIZE = 0.2
RANDOM_SEED = 42
NUM_RUNS = 10

# 1) Read CSV
raw = File.read(csv_path)
raw.sub!("\xEF\xBB\xBF", "")
csv   = CSV.parse(raw, headers: true, col_sep: ';')
total = csv.size

# 2) Prepare features and labels
feature_names = csv.headers - ['ID', 'DM_or_PreDM']
cat_features = ['Gender', 'Ethnicity']
num_features = feature_names - cat_features

# Gather unique categories for encoding
cat_values = {}
cat_features.each do |f|
  cat_values[f] = csv.map { |row| row[f].to_s.strip.downcase }.uniq
end

logger.info "Preprocessing #{total} rows…"
examples = []
labels   = []

csv.each_with_index do |row, idx|
  features = feature_names.map do |f|
    if cat_features.include?(f)
      val = row[f].to_s.strip.downcase
      cat_values[f].index(val) || 0
    else
      v = row[f]
      v.nil? || v.strip.empty? ? 0.0 : v.to_f
    end
  end
  examples << features
  labels << (row['DM_or_PreDM'].to_s.strip.upcase == 'TRUE' ? 1 : 0)
  if ((idx + 1) % (total / 10.0).ceil).zero? || idx + 1 == total
    pct = ((idx + 1) / total.to_f * 100).round(1)
    logger.info "Processed #{idx+1}/#{total} (#{pct}%)"
  end
end

x = Numo::DFloat.cast(examples)
y = Numo::Int32.cast(labels)

# Initialize variables to track best model across all runs
best_overall_model = nil
best_overall_score = -1.0
best_overall_name = nil
best_overall_params = nil
best_overall_features = nil
best_overall_scaler = nil
best_overall_selected_idx = nil

NUM_RUNS.times do |run|
  logger.info "\n=== Starting Run #{run + 1}/#{NUM_RUNS} ==="
  
  # 3) Train/test split
  splitter = Rumale::ModelSelection::StratifiedShuffleSplit.new(n_splits: 1, test_size: TEST_SIZE, random_seed: RANDOM_SEED + run)
  train_ids, test_ids = splitter.split(x, y).first
  x_train, x_test = x[train_ids, true], x[test_ids, true]
  y_train, y_test = y[train_ids], y[test_ids]

  # 4) Feature scaling
  scaler = Rumale::Preprocessing::StandardScaler.new
  x_train_scaled = scaler.fit_transform(x_train)
  x_test_scaled = scaler.transform(x_test)

  # 5) Feature selection (Random Forest importance)
  rf_selector = Rumale::Ensemble::RandomForestClassifier.new(n_estimators: 100, random_seed: RANDOM_SEED + run)
  rf_selector.fit(x_train_scaled, y_train)
  importances = rf_selector.feature_importances
  selected_idx = importances.to_a.each_with_index.select { |imp, _| imp > 0.01 }.map(&:last)
  # Fallback: if no features selected, use all
  selected_idx = (0...x_train_scaled.shape[1]).to_a if selected_idx.empty?
  x_train_sel = x_train_scaled[true, selected_idx]
  x_test_sel = x_test_scaled[true, selected_idx]
  selected_features = feature_names.values_at(*selected_idx)
  logger.info "Selected #{selected_features.size} important features: #{selected_features.join(', ')}"

  # 6) Model selection and hyperparameter tuning
  models = [
    {
      name: 'SVM',
      model: Rumale::LinearModel::SVC,
      params: [
        { reg_param: 10.0 },
        { reg_param: 1.0 },
        { reg_param: 0.1 }
      ]
    },
    {
      name: 'RandomForest',
      model: Rumale::Ensemble::RandomForestClassifier,
      params: [
        { n_estimators: 50, max_depth: 5, random_seed: RANDOM_SEED + run },
        { n_estimators: 100, max_depth: 10, random_seed: RANDOM_SEED + run },
        { n_estimators: 200, max_depth: nil, random_seed: RANDOM_SEED + run }
      ]
    },
    {
      name: 'GradientBoosting',
      model: Rumale::Ensemble::GradientBoostingClassifier,
      params: [
        { n_estimators: 50, learning_rate: 0.01, max_depth: 3, random_seed: RANDOM_SEED + run },
        { n_estimators: 100, learning_rate: 0.1, max_depth: 5, random_seed: RANDOM_SEED + run },
        { n_estimators: 200, learning_rate: 0.3, max_depth: 7, random_seed: RANDOM_SEED + run }
      ]
    }
  ]

  best_model = nil
  best_score = -1.0
  best_name = nil
  best_params = nil

  logger.info "Starting model selection and hyperparameter tuning..."
  models.each do |m|
    m[:params].each do |params|
      model = m[:model].new(**params)
      model.fit(x_train_sel, y_train)
      y_pred = model.predict(x_test_sel)
      tp = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 1 && t == 1 }
      fp = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 1 && t == 0 }
      fn = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 0 && t == 1 }
      precision = tp.to_f / (tp + fp + 1e-10)
      recall = tp.to_f / (tp + fn + 1e-10)
      f1 = 2 * precision * recall / (precision + recall + 1e-10)
      logger.info "#{m[:name]} params #{params.inspect} => F1: #{'%.4f' % f1}"
      if f1 > best_score
        best_score = f1
        best_model = model
        best_name = m[:name]
        best_params = params
      end
    end
  end

  # After model selection, check if best_model is nil
  if best_model.nil?
    raise "No model was selected in run #{run + 1}. Please check your data and model parameters."
  end

  # 7) Final evaluation
  y_pred = best_model.predict(x_test_sel)
  correct = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == t }
  accuracy = correct.to_f / y_test.size

  tp = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 1 && t == 1 }
  fp = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 1 && t == 0 }
  fn = y_pred.to_a.zip(y_test.to_a).count { |p, t| p == 0 && t == 1 }
  precision = tp.to_f / (tp + fp + 1e-10)
  recall = tp.to_f / (tp + fn + 1e-10)
  f1 = 2 * precision * recall / (precision + recall + 1e-10)

  # Create ModelPerformance record
  ModelPerformance.create!(
    accuracy: accuracy,
    precision: precision,
    recall: recall,
    f1_score: f1,
    total_predictions: y_test.size,
    correct_predictions: correct,
    model_version: "v1.#{run + 1}",
    training_date: Time.current,
    model_type: best_name,
    model_params: best_params.to_json,
    selected_features: selected_features.to_json
  )

  logger.info "🏁 Run #{run + 1} metrics:"
  logger.info "   Accuracy:  #{'%.2f' % (accuracy * 100)}%"
  logger.info "   Precision: #{'%.2f' % (precision * 100)}%"
  logger.info "   Recall:    #{'%.2f' % (recall * 100)}%"
  logger.info "   F1 Score:  #{'%.2f' % (f1 * 100)}%"
  logger.info "   Model:     #{best_name}"
  logger.info "   Params:    #{best_params.inspect}"

  # Update best overall model if this run was better
  if f1 > best_overall_score
    best_overall_score = f1
    best_overall_model = best_model
    best_overall_name = best_name
    best_overall_params = best_params
    best_overall_features = selected_features
    best_overall_scaler = scaler
    best_overall_selected_idx = selected_idx
  end
end

# Save the best model from all runs
File.open(model_path, 'wb') do |f| 
  f.write(Marshal.dump({
    model: best_overall_model, 
    scaler: best_overall_scaler, 
    selected_idx: best_overall_selected_idx, 
    cat_values: cat_values, 
    feature_names: feature_names
  }))
end

logger.info "\n=== Final Results ==="
logger.info "✓ Best overall model (#{best_overall_name}) saved to #{model_path}"
logger.info "   Best F1 Score: #{'%.2f' % (best_overall_score * 100)}%"
logger.info "   Best Features: #{best_overall_features.join(', ')}"
logger.info "   Best Params:   #{best_overall_params.inspect}"
