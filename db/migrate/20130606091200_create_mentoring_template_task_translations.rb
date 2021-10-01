class CreateMentoringTemplateTaskTranslations< ActiveRecord::Migration[4.2]
  def up
    # Dummy table creation to make sure the generate fixtures doesn't have issues
    create_table :mentoring_template_task_translations do |t|
      t.timestamps null: false
    end

    # MentoringTemplate::Task.create_translation_table!({
    #   title: :string
    # }, {
    #   migrate_data: true
    # })
  end

  def down
    # MentoringTemplate::Task.drop_translation_table! migrate_data: true
  end
end
