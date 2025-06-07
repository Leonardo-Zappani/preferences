class CreateModelPerformances < ActiveRecord::Migration[7.2]
  def change
    create_table :model_performances do |t|
      t.float :accuracy
      t.float :precision
      t.float :recall
      t.float :f1_score
      t.integer :total_predictions
      t.integer :correct_predictions
      t.string :model_version
      t.datetime :training_date

      t.timestamps
    end
  end
end
