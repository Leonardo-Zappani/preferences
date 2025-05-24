#!/usr/bin/env rails runner

require 'csv'
require 'libsvm'
require 'logger'
require 'thread'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

csv_path   = Rails.root.join('training_data', 'training_data.csv')
model_path = Rails.root.join('training_data', 'svm_trained_model.model')

# 1) Load & strip BOM
raw = File.read(csv_path)
raw.sub!("\xEF\xBB\xBF", "")

# 2) Parse into memory
csv   = CSV.parse(raw, headers: true, col_sep: ';')
total = csv.size

features = []
labels   = []

logger.info "Parsing #{total} rows…"
csv.each_with_index do |row, idx|
  gender_val = row['Gender'].to_s.strip.downcase == 'male' ? 1.0 : 0.0
  nodes = Libsvm::Node.features(
    gender_val,
    row['Age'].to_f,
    row['Weight'].to_f,
    row['Height'].to_f
  )
  features << nodes
  labels   << (row['DM_or_PreDM'].to_s.strip.upcase == 'TRUE' ? 1 : 0)

  # log every 10% (or at end)
  if (idx + 1) % (total / 10.0).ceil == 0 || idx + 1 == total
    pct = ((idx + 1) / total.to_f * 100).round(1)
    logger.info "Parsed #{idx+1}/#{total} (#{pct}%)"
  end
end

# 3) Train on full dataset
logger.info "Training final model on all #{total} instances…"
problem = Libsvm::Problem.new
problem.set_examples(labels, features)

param = Libsvm::SvmParameter.new.tap do |p|
  p.cache_size  = 10
  p.eps         = 1e-5
  p.degree      = 5
  p.gamma       = 0.01
  p.c           = 100
  p.kernel_type = Libsvm::KernelType::LINEAR
end

model = Libsvm::Model.train(problem, param)
model.save(model_path.to_s)
logger.info "✓ Model saved to #{model_path}"

# 4) Parallel 10-fold CV
nfold = 10
logger.info "Starting #{nfold}-fold cross-validation in parallel…"

# split indices into folds
folds = (0...total).to_a.each_slice((total.to_f/nfold).ceil).to_a.take(nfold)
mutex          = Mutex.new
completed      = 0
correct_counts = []

threads = folds.each_with_index.map do |test_idxs, fold|
  Thread.new do
    logger.info "▶️  Fold #{fold+1}: training on #{total - test_idxs.size} instances…"
    train_idxs = (0...total).to_a - test_idxs

    # build train problem
    tr_problem  = Libsvm::Problem.new
    tr_labels   = train_idxs.map { |i| labels[i] }
    tr_features = train_idxs.map { |i| features[i] }
    tr_problem.set_examples(tr_labels, tr_features)

    # train & test this fold
    fold_model = Libsvm::Model.train(tr_problem, param)
    correct    = test_idxs.count { |i| fold_model.predict(features[i]) == labels[i] }

    mutex.synchronize do
      correct_counts << correct
      completed += 1
      pct = (completed / nfold.to_f * 100).round(1)
      logger.info "✅ Fold #{fold+1} done (#{completed}/#{nfold}, #{pct}%)"
    end
  end
end

# wait & report
threads.each(&:join)
total_correct = correct_counts.sum
accuracy      = (total_correct.to_f / total) * 100
logger.info "🏁 #{nfold}-fold CV accuracy: #{'%.2f' % accuracy}%"
