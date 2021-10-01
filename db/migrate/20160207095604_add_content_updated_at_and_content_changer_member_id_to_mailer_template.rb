
class AddContentUpdatedAtAndContentChangerMemberIdToMailerTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mailer_templates, :content_changer_member_id, :integer
    add_column :mailer_templates, :content_updated_at, :datetime

    add_index :mailer_templates, :content_changer_member_id
  end
end
