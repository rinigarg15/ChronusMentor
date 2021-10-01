class CreateSurveyResponseColumns< ActiveRecord::Migration[4.2]
  def change
    create_table :survey_response_columns do |t|
      t.belongs_to :survey
      t.belongs_to :profile_question
      t.string :column_key
      t.integer :position
      t.integer :survey_question_id
      t.integer :ref_obj_type
      t.timestamps null: false
    end

    add_index :survey_response_columns, :survey_id
    add_index :survey_response_columns, :profile_question_id
    add_index :survey_response_columns, :survey_question_id
  end
end
