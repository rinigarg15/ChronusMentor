# == Schema Information
#
# Table name: mailer_widgets
#
#  id         :integer          not null, primary key
#  program_id :integer          not null
#  uid        :string(255)      not null
#  source     :text(16777215)
#  created_at :datetime
#  updated_at :datetime
#

class Mailer::Widget < ActiveRecord::Base
  self.table_name = 'mailer_widgets'

  sanitize_attributes_content :source
  belongs_to_program_or_organization

  validates :program_id, :presence => true
  validates :uid, :presence => true, :uniqueness => {:scope => :program_id}
  validate :valid_source_tags

  translates :source

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:uid, :source],
    :update => [:uid, :source]
  }

  def self.populate_mailer_widget_for_all_locales(mailer_widget, widget_params, other_locales)
    widget = WidgetTag.get_descendant(mailer_widget.uid)
    status = false

    begin
      num_translations = mailer_widget.translations.count
      if num_translations.zero? && mailer_widget[:source].nil?
        mailer_widget.update_attributes!(widget_params)
        mailer_widget.translations.destroy_all
      else
        widget_params[:source] = widget_params[:source] || mailer_widget.translations.find_by(locale: I18n.locale).try(:source) || widget.default_template
        overwrite_default_locale_entry = mailer_widget.translations.find_by(locale: I18n.default_locale).nil? && I18n.locale != I18n.default_locale
        mailer_widget.update_attributes!(widget_params)
        other_locales.each do |locale|
          if mailer_widget.translations.where(:locale => locale).empty? || (locale == I18n.default_locale && overwrite_default_locale_entry)
            GlobalizationUtils.run_in_locale(locale) do
              mailer_widget.source = widget.default_template
              mailer_widget.save!
            end
          end
        end
      end
      status = true
    rescue => exception
      status = false
    ensure
      return status
    end
  end

  def self.add_translation_for_existing_mailer_widgets(organization, language)
    locale = language.language_name.to_s
    organization.mailer_widgets.each { |mailer_widget| mailer_widget.add_default_translation_if_not_exists(locale) }
    organization.programs.each do |program|
      program.mailer_widgets.each { |mailer_widget| mailer_widget.add_default_translation_if_not_exists(locale) }
    end
  end

  def add_default_translation_if_not_exists(locale)
    return if self.translations.empty? || self.translations.find{|translation| translation.locale.to_s == locale}.present?
    GlobalizationUtils.run_in_locale(locale) do
      widget = WidgetTag.get_descendant(self.uid)
      self.source  = widget.default_template
      self.save!
    end
  end

  private

  def valid_source_tags
  	if self.uid && self.source.present?
      widget = WidgetTag.get_descendant(self.uid)
      allowed_tags    = widget.get_tags_from_widget.keys.collect(&:to_s)

      source_tags = []

      begin
        source_tags  = ChronusActionMailer::Base.get_tokens_from(self.source)
      rescue Mustache::Parser::SyntaxError
        self.errors.add(:source, "feature.email.error.no_flower_braces".translate)
        return
      end

      invalid_tags = source_tags - allowed_tags

      if invalid_tags.any?
        tag_string = invalid_tags.collect{|t| "{{#{t}}}"}.join(", ")
        self.errors.add(:source, "feature.email.error.invalid_tags".translate(tag_string: tag_string))
      end
    end
  end
end
