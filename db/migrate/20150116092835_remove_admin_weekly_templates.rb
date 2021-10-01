class RemoveAdminWeeklyTemplates< ActiveRecord::Migration[4.2]
  def up
    admin_weekly_templates = Mailer::Template.where(uid: AdminWeeklyStatus.mailer_attributes[:uid])
    admin_weekly_templates.each do |template|
      template.subject = AdminWeeklyStatus.mailer_attributes[:subject].call
      template.source = AdminWeeklyStatus.default_email_content_from_path(AdminWeeklyStatus.mailer_attributes[:view_path])
      template.save!
    end   
  end

  def down
  end
end
