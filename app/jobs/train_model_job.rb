class TrainModelJob < ApplicationJob
  include SuckerPunch::Job
  queue_as :default

  PATH_TO_TRAINING_DATA = Rails.root.join('lib', 'seeds', 'training_data.csv')
  PATH_TO_TRAINED_MODEL  = Rails.root.join('lib', 'seeds', 'svm_trained_model.model')

  # Now accepts gender and age too
  # gender: 'male' or 'female'
  # age:    integer
  # is_dog_person: 'TRUE' or 'FALSE'
  def perform(prediction_id, gender, age, weight, height, is_dog_person)
    logger.debug "TrainModelJob.perform(##{prediction_id}, #{gender}, age=#{age}, w=#{weight}, h=#{height}, dog=#{is_dog_person})"

    ActiveRecord::Base.connection_pool.with_connection do
      append_training_data(gender, age, weight, height, is_dog_person)

      # Read the CSV with headers, semicolon sep, strip BOM and whitespace
      raw = File.read(PATH_TO_TRAINING_DATA)
      raw.sub!("\xEF\xBB\xBF", "")  # drop BOM if present

      csv = CSV.parse(raw,
                      headers:           true,
                      col_sep:           ';',
                      encoding:          'ISO-8859-1',
                      header_converters: ->(h){ h.strip })

      # build feature vectors
      input_params = csv.map do |row|
        # convert gender to 0/1, age/weight/height to floats
        nodes = []
        nodes << Libsvm::Node.new(1, row['Gender'].downcase == 'male' ? 1.0 : 0.0)
        nodes << Libsvm::Node.new(2, row['Age'].to_f)
        nodes << Libsvm::Node.new(3, row['Weight'].to_f)
        nodes << Libsvm::Node.new(4, row['Height'].to_f)
        nodes
      end

      # labels: map 'TRUE'/'FALSE' to 1/0
      labels = csv.map { |row| row['DM_or_PreDM'].strip.upcase == 'TRUE' ? 1 : 0 }

      # get unique label names (just [0,1] here)
      class_indexes = labels.uniq.sort

      problem = Libsvm::Problem.new
      problem.set_examples(labels, input_params)

      parameter = Libsvm::SvmParameter.new.tap do |p|
        p.cache_size  = 10
        p.eps         = 0.00001
        p.degree      = 5
        p.gamma       = 0.01
        p.c           = 100
        p.kernel_type = Libsvm::KernelType::LINEAR
      end

      model = Libsvm::Model.train(problem, parameter)
      model.save(PATH_TO_TRAINED_MODEL.to_s)

      accuracy = calculate_accuracy(problem, parameter, labels, class_indexes)
      save_accuracy(prediction_id, accuracy)

      logger.debug "TrainModelJob complete—accuracy=#{'%.2f' % accuracy}%"
    end
  end

  private

  # Append a full row matching headers: Gender;Age;DM_or_PreDM;Weight;Height
  def append_training_data(gender, age, weight, height, is_dog_person)
    CSV.open(PATH_TO_TRAINING_DATA, 'ab',
             col_sep:  ';',
             encoding: 'ISO-8859-1') do |csv|
      csv << [gender, age, is_dog_person, weight, height]
    end
  end

  def calculate_accuracy(problem, parameter, true_labels, class_indexes)
    nfold  = 10
    result = Libsvm::Model.cross_validation(problem, parameter, nfold)
    predicted = result.map { |lab| class_indexes[lab] }

    correct = predicted.zip(true_labels).count { |pred, actual| pred == actual }
    (correct.to_f / true_labels.size) * 100.0
  end

  def save_accuracy(prediction_id, accuracy)
    return unless prediction_id.positive?

    Prediction.find(prediction_id)
              .update_columns(metric_1: accuracy)
  end
end
