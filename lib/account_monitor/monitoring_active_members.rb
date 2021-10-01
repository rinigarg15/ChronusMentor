module AccountMonitor
  class MonitoringActiveMembers
    extend AccountMonitor::AccountMonitorHelper

    class << self
      # Getting hash of organization id with there number of active members present atleast in one track
      def get_org_ids_with_active_members_count
        Member.joins(:users).where("users.state='#{User::Status::ACTIVE}'").distinct.group("members.organization_id").count
      end

      # Get count of active organizations
      def get_active_organizations
        Organization.active.pluck(:id)
      end

      # Monitor Organizations whose number of active members which are present atleast in one track are crossing SLA. 
      # Whitelist those organizations in account_monitor.yml.
      def active_member_monitor
        active_members_count_hash = get_org_ids_with_active_members_count
        whitelisting_criteria = get_whitelisting_criteria

        return if (whitelisting_criteria.blank? || whitelisting_criteria["active_members"].blank?)

        whitelisting_limits = whitelisting_criteria["active_members"]["max_limit"]
        whitelisted_orgs = get_whitelisted_orgs(whitelisting_criteria["active_members"]["exclusions"])
        defaulter_orgs = {}

        get_active_organizations.each do |organization_id|
          active_member_count = active_members_count_hash[organization_id]
          if active_member_count > whitelisting_limits
            if whitelisted_orgs[organization_id].blank?
              defaulter_orgs[organization_id] = { :active_members => active_member_count, :limits => whitelisting_limits }
            elsif active_member_count > whitelisted_orgs[organization_id]
              defaulter_orgs[organization_id] = { :active_members => active_member_count, :limits => whitelisted_orgs[organization_id] }
            end
          end
        end

        send_mail("Organization with Org. Id.:#{defaulter_orgs.keys} has more than SLA active members present atleast in one track", defaulter_orgs) if defaulter_orgs.size > 0
      end
    end
  end
end