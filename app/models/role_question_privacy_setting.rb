# == Schema Information
#
# Table name: role_question_privacy_settings
#
#  id               :integer          not null, primary key
#  role_question_id :integer
#  role_id          :integer
#  setting_type     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class RoleQuestionPrivacySetting < ActiveRecord::Base

  module SettingType
    ROLE = 1
    CONNECTED_MEMBERS = 2

    def self.all
      [ROLE, CONNECTED_MEMBERS]
    end
  end

  belongs_to :role_question
  belongs_to :role

  validates :role_question, presence: true
  validates :setting_type, presence: true, inclusion: { :in => SettingType.all }
  validates :role, presence: true, if: ->(setting){ setting.setting_type == SettingType::ROLE }

  scope :by_role, Proc.new {|role_ids| where(setting_type: SettingType::ROLE, role_id: role_ids) }

  def self.restricted_privacy_setting_options_for(program)
    values = []
    if program.engagement_enabled?
      values << {
                  label: "feature.profile_customization.label.users_connections".translate(mentoring_connections: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).try(:pluralized_term_downcase)),
                  privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED,
                  privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS, role_id: nil}
                }
    end
    program.roles.non_administrative.each do |role|
      values << {
                  label: "feature.program.content.all_of_role".translate(role_name: program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).pluralized_term_downcase),
                  privacy_type: RoleQuestion::PRIVACY_SETTING::RESTRICTED,
                  privacy_setting: {setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: role.id}
                }
    end
    values
  end

  def self.has_all_settings?(program, privacy_settings)
    all_settings = self.restricted_privacy_setting_options_for(program).collect { |setting| setting[:privacy_setting] }
    settings = privacy_settings.collect { |setting| setting.attributes.symbolize_keys.slice(:setting_type, :role_id) }
    (all_settings - settings).blank?
  end

end
