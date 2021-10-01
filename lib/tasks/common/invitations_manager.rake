# USAGE: rake common:invitations_manager:expire_pending_invites DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> DATE=<"DD/MM/YYYY"> TIMEZONE=<timezone>
# EXAMPLE: rake common:invitations_manager:expire_pending_invites DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1,p2" DATE="24/11/2017" TIMEZONE="Pacific Time (US & Canada)"

namespace :common do
  namespace :invitations_manager do
    desc "Expire the pending invites in program(s)"
    task expire_pending_invites: :environment do
      Common::RakeModule::Utils.execute_task do
        date = ENV["DATE"].to_date.in_time_zone(ENV["TIMEZONE"])
        programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
        programs.each do |program|
          pending_invites = ProgramInvitation::KendoScopes.status_filter("value" => "feature.program_invitations.kendo.filters.checkboxes.statuses.pending".translate).where(program_id: program.id)
          pending_invites_size = pending_invites.size
          pending_invites_jobs = CampaignManagement::ProgramInvitationCampaignMessageJob.where(abstract_object_id: pending_invites.pluck(:id))
          pending_invites_jobs.delete_all
          pending_invites.update_all(expires_on: date)
          Common::RakeModule::Utils.print_success_messages("Expired the pending #{pending_invites_size} invite(s) in #{program.url}!")
        end
      end
    end
  end
end