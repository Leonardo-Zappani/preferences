class AddDiabetesFieldsToPredictions < ActiveRecord::Migration[7.2]
  def change
    add_column :predictions, :gender, :string
    add_column :predictions, :age, :integer
    add_column :predictions, :dm_label, :boolean
  end
end
