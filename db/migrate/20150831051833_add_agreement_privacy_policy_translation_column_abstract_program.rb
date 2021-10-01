class AddAgreementPrivacyPolicyTranslationColumnAbstractProgram< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(AbstractProgram, :agreement, "text")
    add_translation_column(AbstractProgram, :privacy_policy, "text")
  end

  def down
    remove_column :program_translations, :agreement
    remove_column :program_translations, :privacy_policy
  end
end
