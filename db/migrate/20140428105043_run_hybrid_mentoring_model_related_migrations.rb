class RunHybridMentoringModelRelatedMigrations< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_links do |t|
      t.belongs_to :child_template
      t.belongs_to :parent_template

      t.timestamps null: false
    end
    add_index :mentoring_model_links, :child_template_id
    add_index :mentoring_model_links, :parent_template_id
    add_column :mentoring_models, :mentoring_model_type, :string, default: MentoringModel::Type::BASE
    add_column :programs, :hybrid_templates_enabled, :boolean, default: false
  end
end
