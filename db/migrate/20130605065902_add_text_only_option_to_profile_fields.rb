class AddTextOnlyOptionToProfileFields< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_questions, :text_only_option, :boolean, :default => false
  end
end
