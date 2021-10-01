# == Schema Information
#
# Table name: organization_features
#
#  id              :integer          not null, primary key
#  organization_id :integer
#  feature_id      :integer
#  enabled         :boolean          default(TRUE)
#

class OrganizationFeature < ActiveRecord::Base

  WITH_DEPENDANCIES = [
    FeatureName::OFFER_MENTORING
  ]
  WITH_MAIL_DEPENDANCIES = [FeatureName::CALENDAR_SYNC]
  WITH_FEATURE_DEPENDENCIES = [FeatureName::MENTOR_TO_MENTEE_MATCHING]
  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  belongs_to_program_or_organization :program, :foreign_key => 'organization_id'
  belongs_to :feature

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  validates_presence_of   :organization, :feature
  validates_uniqueness_of :feature_id, :scope => :organization_id

  after_save :update_role_permissions, :update_email_dependencies, :handle_feature_dependencies

  def organization
    self.program
  end

  private

  def update_role_permissions
    if WITH_DEPENDANCIES.include?(self.feature.name)
      method_name = self.feature.name
      self.organization.send("invoke_feature_dependancy_#{method_name}", self.enabled?)
      if self.organization.is_a?(Organization)
        self.organization.programs.each{|p| p.send("invoke_feature_dependancy_#{method_name}", self.enabled?) unless p.permanently_disabled_features.include?(self.feature.name)}
      end
    end
  end

  def update_email_dependencies
    feature_name = self.feature.name
    if WITH_MAIL_DEPENDANCIES.include?(feature_name) && self.enabled?
      organization = self.organization
      email_uids_to_enable = FeatureName.dependent_emails[feature_name][:enabled].collect{|mailer|mailer.mailer_attributes[:uid]}
      if organization.is_a?(Program)
        Mailer::Template.enable_mailer_templates_for_uids(organization, email_uids_to_enable)
      else
        program_ids_with_feature_disabled = organization.get_programs_with_feature_disabled(self.feature)
        organization.programs.where.not(id: program_ids_with_feature_disabled).each do |program|
           Mailer::Template.enable_mailer_templates_for_uids(program, email_uids_to_enable)
        end
      end
    end
  end

  def handle_feature_dependencies
    feature_name = self.feature.name
    if WITH_FEATURE_DEPENDENCIES.include?(feature_name)
      self.organization.delay(queue: DjQueues::HIGH_PRIORITY).send("handle_feature_dependency_#{feature_name}", self.enabled?)
    end
  end
end
