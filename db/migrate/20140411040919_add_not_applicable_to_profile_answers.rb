class AddNotApplicableToProfileAnswers< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_answers, :not_applicable, :boolean, :default => false
  end
end
