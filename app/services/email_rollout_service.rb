class EmailRolloutService
  def initialize(prog_or_org, user_or_member)
    @prog_or_org = prog_or_org
    @mailer_templates = @prog_or_org.mailer_templates.includes(:translations).group_by(&:uid)
    @user_or_member = user_or_member
  end

  def rollout_applicable?(uid)
    rollout_enabled? && mailer_template_present?(uid) && !program_rollouts.include?(uid) && !admin_rollouts.include?(uid)
  end

  def show_rollout_update_all?
    rollout_enabled? && !@user_or_member.dismissed_rollout_emails.where(email_id: nil).present?
  end

  private

  def program_rollouts
    @program_rollouts ||= @prog_or_org.actioned_rollout_emails.pluck(:email_id)
  end

  def admin_rollouts
    @admin_rollouts ||= @user_or_member.dismissed_rollout_emails.pluck(:email_id)
  end

  def rollout_enabled?
    @prog_or_org.rollout_enabled? && !@prog_or_org.actioned_rollout_emails.where(email_id: nil).present?
  end

  def mailer_template_present?(uid)
    @mailer_templates[uid].present?
  end
end