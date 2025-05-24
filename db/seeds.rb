#!/usr/bin/env rails runner

require 'csv'

# adjust to wherever you’ve put your CSV
csv_path = Rails.root.join('training_data', 'training_data.csv')

# open and iterate
CSV.foreach(csv_path, headers: true, col_sep: ';') do |row|
  # build a hash of attributes
  attrs = {
    gender:      row['Gender'].downcase,
    age:         row['Age'].to_i,
    # assuming your model has a boolean column :dm_or_predm
    dm_label: row['DM_or_PreDM'].to_s.upcase == 'TRUE',
    weight:      row['Weight'].to_f,
    height:      row['Height'].to_f
  }

  # create (or use create! if you want it to blow up on validation errors)
  record = Prediction.create(attrs)

  if record.persisted?
    puts "✓ Created Prediction ##{record.id}"
  else
    puts "✗ Failed on row #{row.to_h.inspect}: #{record.errors.full_messages.join(', ')}"
  end
rescue StandardError => e
  puts "✗ Error processing row #{row.to_h.inspect}: #{e.message}"
end
