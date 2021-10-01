class AddBrowserWarningToOrganization< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
  	bw = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_browser_warning_content.yml")).result)
    browser_warning_content = bw.inject{|hash,val| (hash ||= {}).merge!(val)}
    add_column :programs, :browser_warning, :text

    Organization.all.each do |org|
      org.update_column(:browser_warning, browser_warning_content[I18n.default_locale.to_s])
    end

    add_translation_column(AbstractProgram, :browser_warning, "text")

    Organization.all.each do |org|
      locales = org.languages.collect(&:language_name).collect(&:to_s) & ["en", "fr-FR", "de-DE", "es-ES"]
      locales.each do |locale|
        add_translation_values_for_non_default_locale(locale, org, :browser_warning, browser_warning_content[locale])
      end
    end
  end

  def down
  	remove_column :program_translations, :browser_warning
  	remove_column :programs, :browser_warning
  end
end
