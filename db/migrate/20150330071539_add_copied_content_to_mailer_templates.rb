class AddCopiedContentToMailerTemplates< ActiveRecord::Migration[4.2]
  def change
    add_column :mailer_templates, :copied_content, :integer
  end
end
