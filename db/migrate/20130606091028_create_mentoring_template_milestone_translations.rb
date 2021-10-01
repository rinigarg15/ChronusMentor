class CreateMentoringTemplateMilestoneTranslations< ActiveRecord::Migration[4.2]
  def up
    # Dummy table creation to make sure the generate fixtures doesn't have issues
    create_table :mentoring_template_milestone_translations do |t|
      t.timestamps null: false
    end

    # MentoringTemplate::Milestone.create_translation_table!({
    #   title: :string,
    #   description: :text,
    #   resources: :text
    # }, {
    #   migrate_data: true
    # })
  end

  def down
    # MentoringTemplate::Milestone.drop_translation_table! migrate_data: true
  end
end
