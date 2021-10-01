class CreateCustomizedTermTranslationsTable< ActiveRecord::Migration[4.2]
  def up
    CustomizedTerm.create_translation_table!(
      { term: :string, term_downcase: :string,
        pluralized_term: :string, pluralized_term_downcase: :string,
        articleized_term: :string, articleized_term_downcase: :string},
      { migrate_data: true }
    )
  end

  def down
    CustomizedTerm.drop_translation_table! migrate_data: true
  end
end
