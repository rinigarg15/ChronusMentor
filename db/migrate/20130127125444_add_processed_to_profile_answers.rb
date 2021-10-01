class AddProcessedToProfileAnswers< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_answers, :processed, :boolean, :default => false
    add_column :profile_answers, :zencoder_output_id, :string
  end
end
