# TASK: :remove_dormant_members
# USAGE: rake common:member_manager:remove_dormant_members DOMAIN=<domain> SUBDOMAIN=<subdomain> SKIP_MEMBERSHIP_REQUESTS_CHECK=true|false
# EXAMPLE: rake common:member_manager:remove_dormant_members DOMAIN="localhost.com" SUBDOMAIN="ceg"
#USAGE 2: rake common:member_manager:remove_dormant_members DOMAIN=<domain> SUBDOMAIN=<subdomain> PROFILE_FILTERS=<>
# EXAMPLE: rake common:member_manager:remove_dormant_members DOMAIN="localhost.com" SUBDOMAIN="ceg" PROFILE_FILTERS="{:questions_1=>{\"question\"=>\"23233\", \"operator\"=>\"3\", \"value\"=>\"3.12.2018\", \"choice\"=>\"\"}}"

# TASK: :merge
# USAGE: rake common:member_manager:merge DOMAIN=<domain> SUBDOMAIN=<subdomain> EMAILS_MAP=<>
# EXAMPLE: rake common:member_manager:merge DOMAIN="localhost.com" SUBDOMAIN="ceg" EMAILS_MAP="{\"moon@chronus.com\"=>\"sun@chronus.com\"}"

namespace :common do
  namespace :member_manager do
    desc "Removes dormant members in an organization"
    task remove_dormant_members: :environment do
      start_time = Time.now
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      eager_loadables = Common::RakeModule::MemberManager.get_eager_loadables_for_destroying_dormant_members
      dormant_members = organization.members.where(state: Member::Status::DORMANT)

      if ENV["PROFILE_FILTERS"].present?
        profile_questions_hash = ActiveSupport::HashWithIndifferentAccess.new(eval(ENV["PROFILE_FILTERS"]))
        profile_filtered_dormant_member_ids = organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS).send(:refine_profile_params, dormant_members.pluck(:id), profile_questions_hash)
        dormant_members = dormant_members.where(id: profile_filtered_dormant_member_ids)
      end

      dormant_member_ids_with_pending_membership_requests = dormant_members.joins(:membership_requests).where(membership_requests: { status: MembershipRequest::Status::UNREAD }).pluck(:id)
      if dormant_member_ids_with_pending_membership_requests.present?
        if ENV["SKIP_MEMBERSHIP_REQUESTS_CHECK"].try(:to_boolean)
          dormant_members = dormant_members.where.not(id: dormant_member_ids_with_pending_membership_requests)
          Common::RakeModule::Utils.print_alert_messages("Members with the following ids will not be removed as they have pending membership requests : #{dormant_member_ids_with_pending_membership_requests}")
        else
          raise "There are pending membership requests tied to dormant members!"
        end
      end

      counter = 0
      dormant_members.includes(eager_loadables).find_each do |dormant_member|
        dormant_member.destroy
        counter += 1
        print "." if (counter % 100 == 0)
      end
      Common::RakeModule::Utils.print_success_messages("#{counter} dormant members in #{organization.url} have been removed!")
      puts "Time Taken: #{Time.now - start_time} seconds."
    end

    desc "Merges members"
    task merge: :environment do
      Common::RakeModule::Utils.execute_task do
        success_messages = []
        error_messages = []
        emails_map = {}
        eval(ENV["EMAILS_MAP"]).each do |email_to_discard, email_to_retain|
          emails_map[email_to_discard.strip.downcase] = email_to_retain.strip.downcase
        end

        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        admin_member = organization.chronus_admin
        members_to_discard = organization.members.where(email: emails_map.keys).includes(MemberMerger::WhitelistedAssociations.all)
        members_to_retain = organization.members.where(email: emails_map.values)
        email_discard_member_map = members_to_discard.index_by { |member| member.email.strip.downcase }
        email_retain_member_map = members_to_retain.index_by { |member| member.email.strip.downcase }

        emails_map.each do |email_to_discard, email_to_retain|
          member_to_discard = email_discard_member_map[email_to_discard]
          member_to_retain = email_retain_member_map[email_to_retain]

          if MemberMerger.new(member_to_discard, member_to_retain, admin_member).merge
            success_messages << "#{email_to_discard} is merged to #{email_to_retain}!"
          else
            error_messages << "Cannot merge #{email_to_discard} to #{email_to_retain}!"
          end
        end
        Common::RakeModule::Utils.print_success_messages(success_messages)
        Common::RakeModule::Utils.print_error_messages(error_messages)
      end
    end

    # Please double ensure the MEMBER IDS passed, this action is IRREVERSIBLE.
    desc "Remove DUPLICATE Members"
    task remove_duplicates: :environment do
      Common::RakeModule::Utils.execute_task do
        member_ids = ENV["MEMBER_IDS"].split(",").map(&:strip).map(&:to_i)
        member_ids.each_with_index do |member_id, i|
          member = Member.includes(users: :groups).find(member_id)
          if member.users.present?
            raise "Member is part of the group(s)." if member.groups.present?
            raise "Member is part of the meeting(s)." if member.meetings.present?
            member.update_columns(skip_delta_indexing: true, email: member.email.gsub(/@/, "+#{i}\\0"))
          end
          member.destroy
          Common::RakeModule::Utils.print_success_messages("Destroyed member ID: #{member_id}")
        end
      end
    end
  end
end