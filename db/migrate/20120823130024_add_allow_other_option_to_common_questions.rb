class AddAllowOtherOptionToCommonQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :common_questions, :allow_other_option, :boolean, :default => false
  end
end
