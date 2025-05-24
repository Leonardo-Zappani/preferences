#!/usr/bin/env rails runner

require 'csv'
require 'libsvm'

# 1) point at your CSV
csv_path = Rails.root.join('training_data', 'training_data.csv')

features = []
labels   = []

# 2) read every row
CSV.foreach(csv_path, headers: true, col_sep: ';') do |row|
  # normalize inputs
  gender_node = row['Gender'].to_s.strip.downcase == 'male' ? 1.0 : 0.0
  age         = row['Age'].to_f
  weight      = row['Weight'].to_f
  height      = row['Height'].to_f

  # build your Libsvm::Node array
  nodes = Libsvm::Node.features(gender_node, age, weight, height)
  features << nodes

  # TRUE/FALSE → 1/0
  labels << (row['DM_or_PreDM'].to_s.strip.upcase == 'TRUE' ? 1 : 0)
end

# 3) set up the problem
problem = Libsvm::Problem.new
problem.set_examples(labels, features)

param = Libsvm::SvmParameter.new.tap do |p|
  p.cache_size  = 10       # MB
  p.eps         = 0.00001
  p.degree      = 5
  p.gamma       = 0.01
  p.c           = 100
  p.kernel_type = Libsvm::KernelType::LINEAR
end

# 4) train & save
model = Libsvm::Model.train(problem, param)
out   = Rails.root.join('training_data', 'svm_trained_model.model')
model.save(out.to_s)
puts "✅ Model saved to #{out}"

# 5) optional: 10-fold cross-validation
results   = Libsvm::Model.cross_validation(problem, param, 10)
class_idxs = labels.uniq.sort
predicted = results.map { |lab| class_idxs[lab] }
correct   = predicted.zip(labels).count { |pred, actual| pred == actual }
accuracy  = (correct.to_f / labels.size) * 100

puts "🔍 10-fold CV accuracy: #{'%.2f' % accuracy}%"
