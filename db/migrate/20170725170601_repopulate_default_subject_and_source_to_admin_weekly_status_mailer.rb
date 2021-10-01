# Some of the admin weekly status mailer templates contained other language contents in English. Hence repopulating the default contents.
# More details: https://chronus.atlassian.net/browse/AP-16533
class RepopulateDefaultSubjectAndSourceToAdminWeeklyStatusMailer< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      non_default_locales = [:"fr-FR", :"es-ES", :"pt-PT", :"de-DE"]
      subjects_in_non_default_locale = []
      sources_in_non_default_locale = []
      non_default_locales.each do |locale|
        GlobalizationUtils.run_in_locale(locale) do
          subjects_in_non_default_locale << AdminWeeklyStatus.mailer_attributes[:subject].call
          sources_in_non_default_locale << AdminWeeklyStatus.default_email_content_from_path(AdminWeeklyStatus.mailer_attributes[:view_path])
        end
      end

      GlobalizationUtils.run_in_locale(I18n.default_locale) do
        subject_in_default_locale = AdminWeeklyStatus.mailer_attributes[:subject].call
        source_in_default_locale = AdminWeeklyStatus.default_email_content_from_path(AdminWeeklyStatus.mailer_attributes[:view_path])
        admin_weekly_mailer_templates = Mailer::Template.includes(:translations).where(uid: AdminWeeklyStatus.mailer_attributes[:uid])

        admin_weekly_mailer_templates.where(subject: subjects_in_non_default_locale).each { |mailer_template| mailer_template.update_attributes(subject: subject_in_default_locale) }
        admin_weekly_mailer_templates.where(source: sources_in_non_default_locale).each { |mailer_template| mailer_template.update_attributes(source: source_in_default_locale) }
      end
    end
  end

  def down
  end
end
