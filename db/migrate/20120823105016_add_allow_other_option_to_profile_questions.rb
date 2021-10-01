class AddAllowOtherOptionToProfileQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_questions, :allow_other_option, :boolean, :default => false
  end
end
