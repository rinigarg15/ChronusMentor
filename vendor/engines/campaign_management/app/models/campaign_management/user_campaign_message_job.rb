require_relative "exceptions"

class CampaignManagement::UserCampaignMessageJob < CampaignManagement::AbstractCampaignMessageJob 

  belongs_to :campaign_message,
             :foreign_key => "campaign_message_id",
             :class_name => "CampaignManagement::UserCampaignMessage",
             :inverse_of => :jobs

  belongs_to :user, foreign_key: "abstract_object_id"
  validates :campaign_message, :user, :run_at, presence: true

  # UserCampaignMessageJob objects are deleted in bulk using delete_all. Relook at that code, when you add any associations for this table


  # This function doesn't destroy the userjob nor it updates the failed status nor it updates the campaign user status to finished. It is upto the caller to take care of those!
  def create_personalized_message
    begin
      program = user.program
      assign_and_validate_attributes(user, campaign_message)
      admin_member = program.admin_users.first.member
      member = user.member
      mail_locale = Language.for_member(member, program)
      GlobalizationUtils.run_in_locale(mail_locale) do
        mail = UserCampaignEmailNotification.replace_tags(user, @template)
        AdminMessage.create!(
          sender: admin_member,
          subject: mail[:subject].to_s,
          content: mail.body.raw_source.to_s,
          receivers: [member],
          auto_email: true,
          campaign_message: campaign_message,
          program: program
        )
      end
      return true
    rescue Exception => e
      Airbrake.notify(e)
      return false
    end
  end
  
  def assign_and_validate_attributes(user, message)
    assign_and_validate_user_dependencies(user)
    assign_and_validate_message_dependencies(message)
    # validate_if_user_still_in_campaign(user, message)
  end

  def assign_and_validate_user_dependencies(user)
    @program = user.program
    raise CampaignManagement::ProgramNotFound if @program.blank?
    @organization = @program.organization
  end

  def assign_and_validate_message_dependencies(message)
    @template = message.email_template
    raise CampaignManagement::TemplateNotFound if @template.blank?
  end

  # CM_TODO This operation takes some time to complete. We need to determine if it's OK
  # to spend some additional time for all (10K+) jobs. It's double-check anyway, we already
  # checked this on job creation.
  # def validate_if_user_still_in_campaign(user, message)
  #   raise CampaignManagement::UserNotInCampaign unless message.campaign.get_current_user_ids.include?(user.id)
  # end
  private

  def set_abstract_object_type
    self.abstract_object_type = User.name
  end

end
