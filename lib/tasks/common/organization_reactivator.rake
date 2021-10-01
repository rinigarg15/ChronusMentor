# Current Procedure for reactivation
# Find and preferably clear the stale jobs and pending notifications
# Find the organization deactivation date and verify all the migrations past that date included inactive programs and organizations
# Ensure the same with the rake tasks run during the period ( deactivation date - current date )
# The last 2 points are already part of DEV Guidelines - anyway, ensure them for safety #

# TASK: :analyze
# USAGE: rake common:organization_reactivator:analyze DOMAIN=<domain> SUBDOMAIN=<subdomain>
# EXAMPLE: rake common:organization_reactivator:analyze DOMAIN="localhost.com" SUBDOMAIN="ceg"

# TASK: :reactivate
# USAGE: rake common:organization_reactivator:reactivate DOMAIN=<domain> SUBDOMAIN=<subdomain> CLEAR_JOBS=<true|false>
# EXAMPLE: rake common:organization_reactivator:reactivate DOMAIN="localhost.com" SUBDOMAIN="ceg" CLEAR_JOBS="true" DISABLE_MAILS="true" SUSPEND_MEMBERS="true"

namespace :common do
  namespace :organization_reactivator do
    desc "Analyse the pending campaign jobs and notifications"
    task analyze: :environment do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      raise "Organization is already active!" if organization.active?

      abstract_campaign_message_jobs, pending_notifications = Common::RakeModule::OrganizationReactivator.fetch_jobs_and_notifications(organization)
      messages = []
      messages << "Date of deactivation: #{organization.updated_at}"
      messages << "Campaign Jobs: #{abstract_campaign_message_jobs.size}"
      messages << "PendingNotifications: #{pending_notifications.size}"
      messages << "Campaign Jobs Maximum Run at: #{abstract_campaign_message_jobs.maximum(:run_at)}"
      messages << "PendingNotifications Last Created at: #{pending_notifications.maximum(:created_at)}"
      messages << "Analysis Complete!"
      Common::RakeModule::Utils.print_success_messages(messages)
    end

    desc "Reactivate an inactive organization; use CLEAR_JOBS flag to clear pending campaign jobs and notifications"
    task reactivate: :environment do
      Common::RakeModule::Utils.execute_task do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        raise "Organization is already active!" if organization.active?

        if ENV["CLEAR_JOBS"].to_boolean
          abstract_campaign_message_jobs, pending_notifications = Common::RakeModule::OrganizationReactivator.fetch_jobs_and_notifications(organization)
          abstract_campaign_message_jobs.destroy_all
          pending_notifications.destroy_all
          Common::RakeModule::Utils.print_success_messages("Campaign jobs and pending notifications have been cleared!")
        end

        if ENV["DISABLE_MAILS"].to_boolean
          ([organization] + organization.programs).each do |program_or_org|
            create_missing_mailer_templates(program_or_org, program_or_org.mailer_templates.pluck(:uid), program_or_org.is_a?(Organization))
          end
          Mailer::Template.where(program_id: [organization.id] + organization.program_ids).enabled.update_all(enabled: false)
          Common::RakeModule::Utils.print_success_messages("Disabled mailer templates.")
        end

        if ENV["SUSPEND_MEMBERS"].to_boolean
          mentor_admin = organization.members.find_by(email: "mentoradmin@chronus.com")
          members_to_suspend = organization.members.where.not(email: "mentoradmin@chronus.com")
          members_to_suspend.each do |member|
            member.suspend!(mentor_admin, "Suspended by #{organization.admin_custom_term.term || "Administrator"}", false)
          end
          Common::RakeModule::Utils.print_success_messages("Suspended #{members_to_suspend.count} members successfully!")
        end

        organization.active = true
        organization.save!
        Common::RakeModule::Utils.print_success_messages("#{organization.url} has been reactivated!")
      end
    end

    private

    def create_missing_mailer_templates(program_or_org, available_uids, organization_level)
      ChronusActionMailer::Base.get_descendants.each do |mailer_klass|
        uid = mailer_klass.mailer_attributes[:uid]
        next if uid.blank? || uid.in?(available_uids) || (organization_level && mailer_klass.mailer_attributes[:level] != EmailCustomization::Level::ORGANIZATION)
        program_or_org.mailer_templates.create!(uid: uid)
      end
    end
  end
end