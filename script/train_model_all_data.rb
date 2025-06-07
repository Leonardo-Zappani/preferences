#!/usr/bin/env rails runner

require 'csv'
require 'liblinear'
require 'logger'
require 'benchmark'
require 'matrix'
require 'scikit-learn'

logger       = Logger.new(STDOUT)
logger.level = Logger::INFO

csv_path   = Rails.root.join('training_data', 'training_data.csv')
model_path = Rails.root.join('training_data', 'trained_model.model')

# Constants
TEST_SIZE = 0.2
RANDOM_SEED = 42

# 1) read & strip BOM
raw = File.read(csv_path)
raw.sub!("\xEF\xBB\xBF", "")

# 2) parse CSV into examples & labels
csv   = CSV.parse(raw, headers: true, col_sep: ';')
total = csv.size

# Feature preprocessing functions
def normalize_numeric(value)
  return 0.0 if value.nil? || value.to_s.strip.empty?
  value.to_f
end

def encode_categorical(value, categories)
  return 0.0 if value.nil? || value.to_s.strip.empty?
  categories.index(value.strip.downcase) || 0.0
end

# Get unique categories for categorical features
ethnicity_categories = csv.map { |row| row['Ethnicity'].to_s.strip.downcase }.uniq
gender_categories = ['male', 'female']

logger.info "Preprocessing #{total} rows…"
examples = []
labels   = []

csv.each_with_index do |row, idx|
  # Preprocess features
  features = [
    encode_categorical(row['Gender'], gender_categories),
    normalize_numeric(row['Age']),
    encode_categorical(row['Ethnicity'], ethnicity_categories),
    normalize_numeric(row['Family_Income']),
    normalize_numeric(row['Meds']),
    normalize_numeric(row['Weight']),
    normalize_numeric(row['Height']),
    normalize_numeric(row['BMI']),
    normalize_numeric(row['Upper_Leg_Length']),
    normalize_numeric(row['Upper_Arm_Length']),
    normalize_numeric(row['Arm_Circumference']),
    normalize_numeric(row['Waist_Circumference']),
    normalize_numeric(row['Triceps_Skinfold']),
    normalize_numeric(row['Subscapular_Skinfold']),
    normalize_numeric(row['a1c']),
    normalize_numeric(row['Albumin']),
    normalize_numeric(row['Blood_Urea_Nitrogen']),
    normalize_numeric(row['Serum_Creatinine'])
  ]
  
  examples << features
  labels << (row['DM_or_PreDM'].strip.upcase == 'TRUE' ? 1 : 0)

  if ((idx + 1) % (total / 10.0).ceil).zero? || idx + 1 == total
    pct = ((idx + 1) / total.to_f * 100).round(1)
    logger.info "Processed #{idx+1}/#{total} (#{pct}%)"
  end
end

# 3) Split data into training and test sets
train_test_split = Scikit::Learn::ModelSelection.train_test_split(
  examples, labels,
  test_size: TEST_SIZE,
  random_state: RANDOM_SEED
)
train_examples, test_examples, train_labels, test_labels = train_test_split

# 4) Feature scaling
scaler = Scikit::Learn::Preprocessing::StandardScaler.new
train_examples_scaled = scaler.fit_transform(train_examples)
test_examples_scaled = scaler.transform(test_examples)

# 5) Feature selection using Random Forest importance
rf = Scikit::Learn::Ensemble::RandomForestClassifier.new(
  n_estimators: 100,
  random_state: RANDOM_SEED
)
rf.fit(train_examples_scaled, train_labels)
feature_importance = rf.feature_importances_

# Select top features (importance > 0.01)
selected_features = feature_importance.each_with_index
  .select { |imp, _| imp > 0.01 }
  .map { |_, idx| idx }

train_examples_selected = train_examples_scaled.map { |ex| ex.values_at(*selected_features) }
test_examples_selected = test_examples_scaled.map { |ex| ex.values_at(*selected_features) }

logger.info "Selected #{selected_features.size} important features"

# 6) Model selection and hyperparameter tuning
models = {
  'Linear SVM' => {
    model: Scikit::Learn::SVM::LinearSVC,
    params: {
      C: [0.1, 1.0, 10.0, 100.0],
      max_iter: [1000]
    }
  },
  'Random Forest' => {
    model: Scikit::Learn::Ensemble::RandomForestClassifier,
    params: {
      n_estimators: [50, 100, 200],
      max_depth: [5, 10, 15, nil]
    }
  },
  'XGBoost' => {
    model: Scikit::Learn::Ensemble::GradientBoostingClassifier,
    params: {
      n_estimators: [50, 100, 200],
      learning_rate: [0.01, 0.1, 0.3],
      max_depth: [3, 5, 7]
    }
  }
}

best_model = nil
best_score = 0
best_params = nil

logger.info "Starting model selection and hyperparameter tuning..."
models.each do |name, config|
  logger.info "Testing #{name}..."
  
  config[:params].each do |param_name, param_values|
    param_values.each do |value|
      params = { param_name => value }
      
      model = config[:model].new(**params)
      model.fit(train_examples_selected, train_labels)
      predictions = model.predict(test_examples_selected)
      
      score = predictions.each_with_index.count { |pred, i| pred == test_labels[i] }.to_f / test_labels.size
      
      if score > best_score
        best_score = score
        best_model = model
        best_params = params
        logger.info "New best model: #{name} with #{param_name}=#{value} (accuracy: #{'%.2f' % (score * 100)}%)"
      end
    end
  end
end

# 7) Train final model with best parameters
logger.info "Training final model with best parameters..."
final_model = best_model
final_model.save(model_path.to_s)
logger.info "✓ Model saved to #{model_path}"

# 8) Evaluate final model
predictions = best_model.predict(test_examples_selected)

# Calculate metrics
correct = predictions.each_with_index.count { |pred, i| pred == test_labels[i] }
accuracy = correct.to_f / test_labels.size

true_positives = predictions.each_with_index.count { |pred, i| pred == 1 && test_labels[i] == 1 }
false_positives = predictions.each_with_index.count { |pred, i| pred == 1 && test_labels[i] == 0 }
false_negatives = predictions.each_with_index.count { |pred, i| pred == 0 && test_labels[i] == 1 }

precision = true_positives.to_f / (true_positives + false_positives)
recall = true_positives.to_f / (true_positives + false_negatives)
f1_score = 2 * (precision * recall) / (precision + recall)

# Log final metrics
logger.info "🏁 Final model metrics:"
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
  total_predictions: test_labels.size,
  correct_predictions: correct,
  model_version: model_version,
  training_date: Time.current,
  selected_features: selected_features.to_json,
  best_params: best_params.to_json
)
logger.info "✓ Performance metrics saved to database"
