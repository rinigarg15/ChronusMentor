class AddFormTypeToSurveys< ActiveRecord::Migration[4.2]
  def up
    add_column :surveys, :form_type, :integer
  end

  def down
    remove_column :surveys, :form_type, :integer
  end
end
