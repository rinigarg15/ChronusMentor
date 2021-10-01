class CreateTranslationTablesForProgramGoalTemplate< ActiveRecord::Migration[4.2]
  def up
    # Dummy table creation to make sure the generate fixtures doesn't have issues
    create_table :program_goal_template_translations do |t|
      t.timestamps null: false
    end
    # Program::GoalTemplate.create_translation_table!({:title => :string, :description => :text}, {migrate_data: true})
  end

  def down
    # Program::GoalTemplate.drop_translation_table! migrate_data: true
  end
end
