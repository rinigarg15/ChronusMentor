class CreateTranslationTablesForThreeSixtySurveys< ActiveRecord::Migration[4.2]
  def up
    ThreeSixty::Competency.create_translation_table!({
      :title => :string,
      :description => :text
    }, {
      :migrate_data => true
    })

    ThreeSixty::Question.create_translation_table!({
      :title => {:type => :text, :null => false}
    }, {
      :migrate_data => true
    })
  end

  def down
    ThreeSixty::Competency.drop_translation_table! :migrate_data => true
    ThreeSixty::Question.drop_translation_table! :migrate_data => true
  end
end
