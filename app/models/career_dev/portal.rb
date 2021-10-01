# == Schema Information
#
# Table name: programs
#
#  id                                                :integer          not null, primary key
#  name                                              :string(255)
#  description                                       :text(65535)
#  created_at                                        :datetime
#  updated_at                                        :datetime
#  user_id                                           :integer
#  allow_one_to_many_mentoring                       :boolean
#  mentoring_period                                  :integer
#  analytics_script                                  :text(65535)
#  agreement                                         :text(4294967295)
#  sort_users_by                                     :integer          default(0)
#  default_max_connections_limit                     :integer          default(5)
#  min_preferred_mentors                             :integer          default(0)
#  max_connections_for_mentee                        :integer
#  theme_id                                          :integer
#  allow_mentoring_requests                          :boolean          default(TRUE)
#  allow_mentoring_requests_message                  :text(65535)
#  inactivity_tracking_period                        :integer          default(2592000)
#  mentor_request_style                              :integer          default(2)
#  footer_code                                       :text(65535)
#  type                                              :string(255)      not null
#  parent_id                                         :integer
#  root                                              :string(255)
#  programs_count                                    :integer
#  logout_path                                       :string(255)
#  active                                            :boolean          default(TRUE)
#  ssl_only                                          :boolean          default(FALSE)
#  privacy_policy                                    :text(65535)
#  mentor_offer_needs_acceptance                     :boolean          default(TRUE)
#  base_program_id                                   :integer
#  subscription_type                                 :integer          default(1)
#  allow_users_to_leave_connection                   :boolean
#  allow_to_change_connection_expiry_date            :boolean          default(FALSE)
#  allow_mentee_withdraw_mentor_request              :boolean          default(FALSE)
#  published                                         :boolean          default(TRUE)
#  max_pending_requests_for_mentee                   :integer
#  fluid_layout                                      :boolean          default(TRUE)
#  cannot_edit_admin_task_owner                      :boolean          default(TRUE)
#  account_name                                      :string(255)
#  allow_private_journals                            :boolean          default(TRUE)
#  allow_connection_feedback                         :boolean          default(TRUE)
#  allow_preference_mentor_request                   :boolean          default(TRUE)
#  show_multiple_role_option                         :boolean          default(FALSE)
#  can_update_root                                   :boolean          default(FALSE), not null
#  email_from_address                                :string(255)
#  allow_users_to_mark_connection_public             :boolean          default(FALSE)
#  prevent_manager_matching                          :boolean          default(FALSE)
#  allow_non_match_connection                        :boolean          default(FALSE)
#  zero_match_score_message                          :text(65535)
#  manager_matching_level                            :integer          default(1)
#  engagement_type                                   :integer
#  connection_limit_permission                       :integer          default(3)
#  hybrid_templates_enabled                          :boolean          default(FALSE)
#  program_type                                      :string(255)
#  number_of_licenses                                :integer
#  needs_meeting_request_reminder                    :boolean          default(FALSE)
#  meeting_request_reminder_duration                 :integer          default(3)
#  needs_mentoring_request_reminder                  :boolean          default(FALSE)
#  mentoring_request_reminder_duration               :integer          default(3)
#  programs_listing_visibility                       :integer          default(0)
#  mentor_request_expiration_days                    :integer
#  needs_project_request_reminder                    :boolean          default(FALSE)
#  project_request_reminder_duration                 :integer          default(3)
#  show_text_type_answers_per_reviewer_category      :boolean          default(TRUE)
#  position                                          :integer
#  meeting_request_auto_expiration_days              :integer
#  auto_terminate_reason_id                          :integer
#  active_mobile_theme                               :integer
#  admin_access_to_mentoring_area                    :integer          default(0)
#  allow_mentoring_mode_change                       :integer          default(0)
#  ssl_certificate_available                         :boolean          default(FALSE)
#  creation_way                                      :integer
#  prevent_past_mentor_matching                      :boolean          default(FALSE)
#  email_theme_override                              :string(255)
#  white_label                                       :boolean          default(FALSE)
#  favicon_link                                      :text(65535)
#  display_custom_terms_only                         :boolean          default(FALSE)
#  zendesk_support_portal                            :boolean          default(FALSE)
#  rollout_enabled                                   :boolean          default(FALSE)
#  audit_user_communication                          :boolean          default(FALSE)
#  processing_weekly_digest                          :boolean          default(FALSE)
#  allow_user_to_send_message_outside_mentoring_area :boolean          default(TRUE)
#  allow_end_users_to_see_match_scores               :boolean          default(TRUE)
#  allow_track_admins_to_access_all_users            :boolean          default(FALSE)
#  browser_warning                                   :text(65535)
#

class CareerDev::Portal < Program
  module ProgramType
    CHRONUS_CAREER = 'career_dev'

    def self.all
      [CHRONUS_CAREER]
    end
  end

  module CreationWay
    MANUAL = 0
    SOLUTION_PACK = 2
  end

  module Permissions
    PUBLISH_ARTICLES = [
      {:label => "employees_publish_articles", :role => RoleConstants::EMPLOYEE_NAME, :permission => "write_article"}]
    def self.content_related
      PUBLISH_ARTICLES
    end
  end

  module CAMPAIGNS
    CSV_FILES = ["career_dev_invitation_campaign.csv"]
  end

  validates :name, presence: true

  def self.program_root_name(n = 1)
    "cd#{n}"
  end

  def disable_program_observer
    true
  end

  def is_career_developement_program?
    true
  end

  def default_role_names
    RoleConstants::DEFAULT_CAREER_DEV_ROLE_NAMES
  end

  def default_survey_types
    Survey::Type.for_portal
  end

  def is_career_developement_program?
    true
  end

  def create_default_roles
    RoleConstants::DEFAULT_CAREER_DEV_ROLE_NAMES.each do |role_name|
      get_role(role_name) || create_role(role_name)
    end
  end

  def create_role(role_name)
    permissions = Permission.where(name: RoleConstants::DEFAULT_CAREER_DEV_ROLE_PERMISSIONS[role_name])
    # Create role with the permissions and default join settings
    role = self.roles.create!(construct_options(role_name, permissions))
    role.add_default_questions_for unless role.administrative?
  end

  def disable_features_by_default
    FeatureName.permenantly_disabled_career_dev_features.each do |feature_name|
      self.enable_disable_feature(feature_name, false)
    end
  end

  def set_position
    self.position = -1
  end

  def send_welcome_email(user, added_by)
    ChronusMailer.welcome_message_to_portal_user(user, added_by).deliver_now
  end

  def notify_added_user(user, creator)
    if user.is_admin_only?
      # No pending email for admin
      deliver_user_added_notifcation_mail(user, creator, :admin_added_directly_notification)
    else
      deliver_user_added_notifcation_mail(user, creator, :portal_member_with_set_of_roles_added_notification, :portal_member_with_set_of_roles_added_notification_to_review_profile)        
    end
  end

  def removed_as_feature_from_ui
    disable_for_career_dev_features = FeatureName.permenantly_disabled_career_dev_features.concat(FeatureName.career_dev_specific_features & FeatureName.organization_level_features)
    return FeatureName.removed_as_feature_from_ui.concat(disable_for_career_dev_features)
  end

  def permanently_disabled_features
    return FeatureName.permenantly_disabled_career_dev_features
  end
  

  def demographic_report_role_based_view_columns
    {
      RoleConstants::EMPLOYEE_NAME => ReportViewColumn::DemographicReport::Key::EMPLOYEES_COUNT
    }
  end

  def management_report_related_custom_term_interpolations
    @_management_report_related_custom_term_interpolations ||= {
      program: self.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase,
      :Program => self.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term
    }
  end

  def self.populate_default_static_content_for_globalization(portal_id)
    portal = CareerDev::Portal.find_by(id: portal_id)
    return unless portal.present?
    locales = [I18n.default_locale] + portal.organization.languages.pluck(:language_name)
    portal.roles_without_admin_role.collect{ |role| role.populate_description_with_default_value_if_nil(locales) }
  end

  private

  def construct_options(role_name, permissions)
    return { :name => role_name, :permissions => permissions, :program => self}.merge(RoleConstants::DEFAULT_CAREER_DEV_ROLE_SETTINGS[role_name])
  end
end
