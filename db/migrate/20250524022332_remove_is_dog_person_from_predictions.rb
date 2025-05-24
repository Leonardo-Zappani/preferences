class RemoveIsDogPersonFromPredictions < ActiveRecord::Migration[7.2]
  def change
    remove_column :predictions, :is_dog_person, :boolean
  end
end
