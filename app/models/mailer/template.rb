# == Schema Information
#
# Table name: mailer_templates
#
#  id                        :integer          not null, primary key
#  program_id                :integer          not null
#  uid                       :string(255)
#  enabled                   :boolean          default(TRUE)
#  source                    :text(16777215)
#  subject                   :text(16777215)
#  created_at                :datetime
#  updated_at                :datetime
#  campaign_message_id       :integer
#  copied_content            :integer
#  content_changer_member_id :integer
#  content_updated_at        :datetime
#

class Mailer::Template < ActiveRecord::Base
	self.table_name = 'mailer_templates'

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:enabled, :subject, :source, :uid],
    :update => [:enabled, :subject, :source, :uid]
  }

  module Status
    ALL = 0
    ENABLED = 1
    DISABLED = 2
  end

  module Customized
    ALL = 0
    CUSTOMIZED = 1
    NON_CUSTOMIZED = 2
  end

  module CopiedContent
    BOTH = 0
    SUBJECT = 1
    SOURCE = 2

    def self.all
      [BOTH, SUBJECT, SOURCE]
    end
  end

  sanitize_attributes_content :source
  belongs_to_program_or_organization
  belongs_to :campaign_message, foreign_key: "campaign_message_id", class_name: "CampaignManagement::AbstractCampaignMessage"

  belongs_to :content_changer_member, class_name: "Member"

  validates :program_id, :presence => true
  validates :uid, :presence => true, :uniqueness => {:scope => :program_id}, :unless => Proc.new {|email_template| email_template.is_a_campaign_message_template?}  
  validates :source, :subject, :presence => true, :if => :campaign_message_id
  validate :source_and_subject_tags
  validates :copied_content, inclusion: { in: CopiedContent.all, allow_nil: true }
  validates :enabled, inclusion: { in: [true] }, if: Proc.new { |email_template| ChronusActionMailer::Base.always_enabled?(email_template.uid) }
  scope :both_copied, -> { where(copied_content: CopiedContent::BOTH)}
  scope :subject_copied, -> { where(copied_content: [CopiedContent::BOTH, CopiedContent::SUBJECT])}
  scope :source_copied, -> { where(copied_content: [CopiedContent::BOTH, CopiedContent::SOURCE])}

  scope :enabled, -> { where(enabled: true)}
  scope :disabled, -> { where(enabled: false)}

  scope :non_campaign_mails, -> { where(campaign_message_id: nil)}

  attr_accessor :belongs_to_cm, :is_valid_on_disabling_calendar

  translates :subject, :source

  def validate_tags_and_widgets_in_subject_and_source(allowed_tags, allowed_widgets)
    source_tags_widgets = {}
    subject_tags_widgets = {}

    begin
      source_tags_widgets  = ChronusActionMailer::Base.get_widget_tag_names(self.source)
    rescue Mustache::Parser::SyntaxError
      self.errors.add(:source, "feature.email.error.no_flower_braces".translate)
      return
    end

    begin
      subject_tags_widgets  = ChronusActionMailer::Base.get_widget_tag_names(self.subject)
    rescue Mustache::Parser::SyntaxError
      self.errors.add(:subject, "feature.email.error.invalid_syntax_style_in_tag".translate)
      return
    end

    invalid_subject_tags = subject_tags_widgets[:tag_names] - allowed_tags
    if invalid_subject_tags.any?
      tag_string = invalid_subject_tags.collect{|t| "{{#{t}}}"}.join(", ")
      self.errors.add(:subject, "feature.email.error.invalid_tags".translate(tag_string: tag_string))
    end

    if subject_tags_widgets[:widget_names].any?
      tag_string = subject_tags_widgets[:widget_names].collect{|t| "{{#{t}}}"}.join(", ")
      self.errors.add(:subject, "feature.email.error.no_widgets".translate(tag_string: tag_string))
    end

    invalid_source_tags = source_tags_widgets[:tag_names] - allowed_tags 
    if invalid_source_tags.any?
      tag_string = invalid_source_tags.collect{|t| "{{#{t}}}"}.join(", ")
      self.errors.add(:source, "feature.email.error.invalid_tags".translate(tag_string: tag_string))
    end

    invalid_source_widgets = source_tags_widgets[:widget_names] - allowed_widgets 
    if invalid_source_widgets.any?
      tag_string = invalid_source_widgets.collect{|t| "{{#{t}}}"}.join(", ")
      self.errors.add(:source, "feature.email.error.invalid_widgets".translate(tag_string: tag_string))
    end
  end

  def is_a_campaign_message_template?
    belongs_to_cm.present? || campaign_message_id.present?
  end

  def is_campaign_message_template_being_created_now?
    belongs_to_cm.present? && !campaign_message_id.present?
  end

  def validate_tags_and_widgets_through_campaign(campaign_id)
    campaign = CampaignManagement::AbstractCampaign.find(campaign_id)
    tags, widgets = campaign.get_supported_tags_and_widgets
    validate_tags_and_widgets_in_subject_and_source(tags, widgets)
    !errors.any?
  end

  def self.change_and_save_templates(template_class)
    templates = Mailer::Template.where(uid: template_class.mailer_attributes[:uid])
    subject = template_class.mailer_attributes[:subject].call
    source = template_class.default_email_content_from_path(template_class.mailer_attributes[:view_path])
    templates.each do |template|
      Mailer::Template.save_template(template, subject, source)
    end
  end

  def self.save_template(template, subject, source)
    template.subject = subject
    template.source = source
    template.save!
  end

  def subject_copied?
    [CopiedContent::BOTH, CopiedContent::SUBJECT].include?(self.copied_content)
  end

  def source_copied?
    [CopiedContent::BOTH, CopiedContent::SOURCE].include?(self.copied_content)
  end

  def clear_subject_and_content(current_member)
    self.update_attributes!(subject: "", source: "", content_changer_member_id: current_member.id, content_updated_at: Time.now)
    self.translations.destroy_all
  end

  def self.reset_content_for(scope)
    scope.enabled.destroy_all
    mailer_template_ids = scope.disabled.pluck(:id)
    Mailer::Template::Translation.where(mailer_template_id: mailer_template_ids).destroy_all
  end

  def self.update_subject_source_params_if_unchanged(params, current_member)
    has_subject_changed = params[:has_subject_changed].to_boolean
    has_source_changed = params[:has_source_changed].to_boolean
    unless has_subject_changed
      params[:mailer_template].delete(:subject)
    end
    unless has_source_changed
      params[:mailer_template].delete(:source)
    end
    update_content_changer_and_updation_time(params, current_member)
    add_copied_content_param(params)
  end

  def self.update_content_changer_and_updation_time(params, current_member)
    if params[:mailer_template][:subject].present? || params[:mailer_template][:source].present?
      params[:mailer_template].merge!({content_changer_member_id: current_member.id, content_updated_at: Time.now})
    end
  end

  def self.add_copied_content_param(params)
    params[:mailer_template].merge!({copied_content: nil}) if (params[:mailer_template][:subject].present? || params[:mailer_template][:source].present?)
    return params
  end

  def self.populate_mailer_template_for_all_locales(mailer_template, mailer_template_params, other_locales)
    email = ChronusActionMailer::Base.get_descendant(mailer_template.uid)
    email_hash = email.mailer_attributes
    status = nil

    begin
      num_translations = mailer_template.translations.count
      if num_translations.zero? && mailer_template_params[:subject].nil? && mailer_template_params[:source].nil?
        mailer_template.update_with_empty_translations(mailer_template_params)
      else
        mailer_template.update_with_translations(mailer_template_params, other_locales, email_hash)
      end
      status = true
    rescue => exception
      status = false
    ensure
      return status
    end
  end

  def self.add_translation_for_existing_mailer_templates(organization, language)
    locale = language.language_name.to_s
    organization.mailer_templates.each { |mailer_template| mailer_template.add_default_translation_if_not_exists_for_non_campaign_templates(locale) }
    organization.programs.each do |program|
      program.mailer_templates.each { |mailer_template| mailer_template.add_default_translation_if_not_exists_for_non_campaign_templates(locale) }
    end
  end

  def add_default_translation_if_not_exists_for_non_campaign_templates(locale)
    return if self.translations.empty? || self.campaign_message_id.present? || self.translations.find{|translation| translation.locale.to_s == locale}.present?
    GlobalizationUtils.run_in_locale(locale) do
      email = ChronusActionMailer::Base.get_descendant(self.uid)
      email_hash = email.mailer_attributes
      self.subject = email_hash[:subject].call
      self.source = ChronusActionMailer::Base.default_email_content_from_path(email_hash[:view_path])
      self.save!
    end
  end

  def self.content_updater_and_updation_time(uid, program)
    mailer_template = program.mailer_templates.find_by(uid: uid)
    content_changer_member = mailer_template.content_changer_member
    updation_time = mailer_template.content_updated_at
    return content_changer_member, updation_time
  end

  def self.content_customized?(prog_or_org, email)
    mailer_template = prog_or_org.mailer_templates.find_by(uid: email.mailer_attributes[:uid])
    return false unless mailer_template.present? && mailer_template.id.present?
    (mailer_template.subject.present? && (MailerTemplatesHelper.handle_space_quotes_in_mail_content(mailer_template.subject) != MailerTemplatesHelper.handle_space_quotes_in_mail_content(email.mailer_attributes[:subject].call))) || (mailer_template.source.present? && (MailerTemplatesHelper.handle_space_quotes_in_mail_content(mailer_template.source) != MailerTemplatesHelper.handle_space_quotes_in_mail_content(email.default_email_content_from_path(email.mailer_attributes[:view_path]))))
  end

  def is_valid_on_disabling_calendar?
    set_instance_variable_within_block_and_reset(:is_valid_on_disabling_calendar, true) do
      valid?
    end
  end

  def self.enable_mailer_templates_for_uids(program, uids)
    mailer_templates = program.mailer_templates.where(uid: uids)
    mailer_templates.update_all(enabled: true)
  end

  def update_with_empty_translations(mailer_template_params)
    self.update_attributes!(mailer_template_params)
    self.translations.destroy_all
  end

  def update_with_translations(mailer_template_params, other_locales, email_hash)
    mailer_template_params[:subject] = get_subject_with_fallback(mailer_template_params, email_hash[:subject])
    mailer_template_params[:source] = get_source_with_fallback(mailer_template_params, email_hash[:view_path])
    overwrite_default_locale_entry = can_overwrite_default_locale_entry?
    self.update_attributes!(mailer_template_params)
    other_locales.each do |locale|
      if self.translations.where(locale: locale).empty? || (locale == I18n.default_locale && overwrite_default_locale_entry)
        GlobalizationUtils.run_in_locale(locale) do
          self.subject = email_hash[:subject].call
          self.source = ChronusActionMailer::Base.default_email_content_from_path(email_hash[:view_path])
          self.save!
        end
      end
    end
  end

  def self.find_or_initialize_mailer_template_with_default_content(correct_level, template_class)
    email_hash = template_class.mailer_attributes
    mailer_template = correct_level.mailer_templates.find_or_initialize_by(uid: email_hash[:uid])
    mailer_template.subject = mailer_template.subject.presence || email_hash[:subject].call
    mailer_template.source = mailer_template.source.presence || template_class.default_email_content_from_path(email_hash[:view_path])

    mailer_template
  end

  private

  def get_subject_with_fallback(mailer_template_params, email_subject)
    get_param_with_fallback(mailer_template_params, :subject) || email_subject.call
  end

  def get_source_with_fallback(mailer_template_params, email_view_path)
    get_param_with_fallback(mailer_template_params, :source) || ChronusActionMailer::Base.default_email_content_from_path(email_view_path)
  end

  def get_param_with_fallback(mailer_template_params, param)
    mailer_template_params[param] || self.translations.find_by(locale: I18n.locale).try(param)
  end


  def can_overwrite_default_locale_entry?
    self.translations.find_by(locale: I18n.default_locale).nil? && I18n.locale != I18n.default_locale
  end

  def get_valid_tags_and_widgets
    if is_a_campaign_message_template?
      # Return here and let the validation happen in campaign observer
      return if is_campaign_message_template_being_created_now?
      campaign_message.campaign.get_supported_tags_and_widgets
    else
      return unless (self.uid && (self.source.present? || self.subject.present?))
      email = ChronusActionMailer::Base.get_descendants.find{|e| e.mailer_attributes[:uid] == self.uid}
      #get_customized_tags from an email are added as allowed_tags to handle preview of emails.
      allowed_tags    = (email.get_tags_from_email.keys.collect(&:to_s) + email.get_customized_tags.keys.collect(&:to_s)).uniq
      allowed_widgets = email.get_widgets_from_email.keys.collect(&:to_s)
      return allowed_tags, allowed_widgets
    end
  end

  def source_and_subject_tags
    allowed_tags, allowed_widgets = get_valid_tags_and_widgets
    allowed_tags -= ChronusActionMailer::Base.mailer_attributes[:tags][:meeting_request_campaign_tags].keys.map(&:to_s) if allowed_tags && @is_valid_on_disabling_calendar
    validate_tags_and_widgets_in_subject_and_source(allowed_tags, allowed_widgets) if (allowed_tags && allowed_widgets)
  end
end
