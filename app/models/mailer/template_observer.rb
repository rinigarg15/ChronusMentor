class Mailer::TemplateObserver < ActiveRecord::Observer

  def before_save(mailer_template)
    if I18n.locale != I18n.default_locale
      default_locale_content = mailer_template.translations.find_by(locale: I18n.default_locale)
      handle_default_locale_content(mailer_template, default_locale_content) if default_locale_content.present?
    end
  end

  private

  def handle_default_locale_content(mailer_template, default_locale_content)
    GlobalizationUtils.run_in_locale(I18n.default_locale) do
      mailer_template.subject = nil if default_locale_content.subject.nil?
      mailer_template.source = nil if default_locale_content.source.nil?
    end
  end

end