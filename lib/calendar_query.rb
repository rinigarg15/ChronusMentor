class CalendarQuery
  class << self
    include OpenAuthUtils::Extensions

    def get_busy_slots_for_members(start_time, end_time, options = {})
      members = options[:members]
      ret_hsh = {}
      members.each do |member|
        ret_hsh[member.id] = {error_occured: false, busy_slots: []}
        member_o_auth_credential_details = get_o_auth_credentials(member, options)
        calendar_key = member_o_auth_credential_details[:calendar_key]
        next unless calendar_key.present?
        member_o_auth_credential_details[:o_auth_credentials].each do |o_auth_credential|
          hsh = o_auth_credential.get_free_busy_slots(start_time, end_time, calendar_key: calendar_key)
          hsh[:busy_slots].each { |slot| ret_hsh[member.id][:busy_slots] << slot }
          handle_errors(hsh, ret_hsh, member)
        end
      end
      ret_hsh
    end

    def get_merged_busy_slots_for_member(start_time, end_time, options)
      busy_slots = get_busy_slots_for_members(start_time, end_time, options)
      return_hash = {error_occured: false, busy_slots: []}
      busy_slots.values.each do |info|
        return_hash[:error_occured] ||= info[:error_occured]
        return_hash[:busy_slots].concat(info[:busy_slots])
      end
      return_hash
    end

    private

    def get_o_auth_credentials(member, options)
      scope, calendar_key = (options[:organization_wide_calendar] ? [member.organization, member.email] : [member, "primary"])
      {o_auth_credentials: scope.o_auth_credentials, calendar_key: calendar_key}
    end

    def handle_errors(hsh, ret_hsh, member)
      [:error_occured, :error_code, :error_message].each { |key| ret_hsh[member.id][key] ||= hsh[key] }
    end
  end
end