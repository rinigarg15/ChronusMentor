class AddIsDraftToCommonAnswer< ActiveRecord::Migration[4.2]
  def change
    add_column :common_answers, :is_draft, :boolean, :default => false
    add_index :common_answers, :is_draft
  end
end
