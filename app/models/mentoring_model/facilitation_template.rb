# == Schema Information
#
# Table name: mentoring_model_facilitation_templates
#
#  id                    :integer          not null, primary key
#  subject               :string(255)
#  message               :text(16777215)
#  send_on               :integer
#  mentoring_model_id    :integer
#  milestone_template_id :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  specific_date         :datetime
#

class MentoringModel::FacilitationTemplate < ActiveRecord::Base

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:message, :subject, :send_on, :specific_date],
    :update => [:message, :subject, :send_on, :specific_date]
  }

  sanitize_attributes_content :message
  belongs_to :mentoring_model
  belongs_to :milestone_template
  has_many :facilitation_delivery_logs, as: :facilitation_delivery_loggable
  translates :subject, :message

  attr_accessor :due_date, :skip_survey_validations

  AUTO_EMAIL_NOTIFICATION_UID = "2xw1lphb"

  # Validations
  validates :mentoring_model_id, :subject, :message, presence: true
  validate :send_on_xor_specific_date
  validate :validate_surveys, :if => :message

  delegate :program, to: :mentoring_model

  scope :send_immediately, -> { where(send_on: 0)}

  acts_as_role_based

  # Date Assigner
  module DueDateType
    PREDECESSOR = "predecessor"
    SPECIFIC_DATE = "specificDate"
  end
  
  def self.compute_due_dates(facilitation_templates)
    facilitation_templates.each do |ft|
      ft.due_date = ft.specific_date.blank? ? ft.send_on : (ft.specific_date.to_i - 1e15)
    end
    facilitation_templates
  end

  def deliver_to_eligible_recipients(group, admin_member)
    eligible_recipients(group, roles.collect(&:id)).each do |user|
      begin
        if !self.facilitation_delivery_logs.where(user_id: user.id, group_id: group.id).exists?
          ActiveRecord::Base.transaction do
            self.facilitation_delivery_logs.create!(user: user, group: group)
            AdminMessage.create_for_facilitation_message(self, user, admin_member, group)
          end
        end
      rescue => error
        Airbrake.notify("FacilitationMessage Delivery failed for user with ID #{user.id}; Error: #{error.message}")
      end
    end
  end

  def prepare_message(recipient_user, group)
    prepared_message = message
    engagement_survey_ids = get_engagement_survey_ids_from_message
    # Engagement surveys
    grouped_survey_links = program.surveys.of_engagement_type.where(:id => engagement_survey_ids).group_by(&:id)
    grouped_survey_links.each do |survey_id, survey| 
      grouped_survey_links[survey_id] = { 
        url: Rails.application.routes.url_helpers.edit_answers_survey_url(survey.first.id, :group_id => group.id, :subdomain => program.organization.subdomain, :host => program.organization.domain, :root => program.root, :src => Survey::SurveySource::MAIL), 
        name: survey.first.name 
      }
    end

    doc = Nokogiri::HTML::DocumentFragment.parse(prepared_message)
    doc.css('a').each do |a_tag|
      if a_tag.attributes["href"].present? && a_tag.attributes["href"].value.match(/engagement_survey_link_\d+/)
        survey_id = a_tag.attributes["href"].value.match(/engagement_survey_link_(\d+)/).captures.first.to_i
        a_tag.attributes["href"].value = grouped_survey_links[survey_id][:url] if grouped_survey_links[survey_id].present?
      end
    end
    prepared_message = doc.to_html

    grouped_survey_links.each do |survey_id, survey_data|
      link = Rinku.auto_link(survey_data[:url]) {|text| survey_data[:name] }
      prepared_message = (link.present? && prepared_message.present?) ? prepared_message.gsub(/\{\{engagement_survey_link_#{survey_id}}\}/, link) : nil
    end
    prepared_message.present? ? [prepared_message, false] : [message, true]
  end

  def get_engagement_survey_ids_from_message
    engagement_survey_links = message.scan(/\{\{engagement_survey_link_\d+\}\}/)
    engagement_survey_links.map{ |link| link.scan(/\d+/).first }
  end

private

  def eligible_recipients(group, role_ids)
    eligible_memberships = group.memberships.select do |membership|
      role_ids.include? membership.role_id
    end
    eligible_memberships.collect(&:user)
  end

  def send_on_xor_specific_date
    if !(send_on.blank? ^ specific_date.blank?)
      errors.add(:facilitation_template, "Specify a send on or a specific date, not both or none")
    end
  end

  def validate_surveys
    return true if self.skip_survey_validations
    engagement_survey_ids = get_engagement_survey_ids_from_message.map(&:to_i)
    survey_ids = program.surveys.of_engagement_type.where(:id => engagement_survey_ids).pluck(:id)
    if engagement_survey_ids.present? && (engagement_survey_ids - survey_ids).any?
      errors.add(:facilitation_template, "activerecord.custom_errors.facilitation_template.survey_invalid".translate)
    end
  end
end
