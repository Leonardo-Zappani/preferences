class AddModelDetailsToModelPerformances < ActiveRecord::Migration[7.2]
  def change
    add_column :model_performances, :model_type, :string
    add_column :model_performances, :model_params, :text
    add_column :model_performances, :selected_features, :text
  end
end
