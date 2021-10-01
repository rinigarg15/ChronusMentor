class CreateGroupClosureReasonTranslations< ActiveRecord::Migration[4.2]
  def up
    GroupClosureReason.create_translation_table!({
      reason: :string
    })
  end

  def down
    GroupClosureReason.drop_translation_table!
  end
end
