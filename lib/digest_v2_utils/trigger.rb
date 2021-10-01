module DigestV2Utils
  class Trigger
    TRIGGER_START_HOUR = 7
    ALLOWED_HOURS_TO_SEND_EMAILS = 3
    EMAIL_SEND_LIMIT_HOUR = TRIGGER_START_HOUR + ALLOWED_HOURS_TO_SEND_EMAILS
    MOST_VIEWED_CONTENT_COUNT = 3

    def start
      selected_time_zones = get_valid_time_zones_at_this_time
      this_time_zone = selected_time_zones[0]
      return unless this_time_zone

      selected_user_ids_grouped_by_program_hsh = selected_user_ids_grouped_by_program(selected_time_zones)
      return if selected_user_ids_grouped_by_program_hsh.blank?

      program_ids = selected_user_ids_grouped_by_program_hsh.keys
      last_program_id = program_ids.last
      BlockExecutor.iterate_fail_safe(program_ids) do |program_id|
        selected_user_ids = selected_user_ids_grouped_by_program_hsh[program_id]
        delay(queue: DjQueues::WEEKLY_DIGEST).send_digest_v2_for_program(program_id, selected_user_ids, this_time_zone, program_id == last_program_id)
      end
    end

    private

    def send_digest_v2_for_program(program_id, selected_user_ids, this_time_zone, set_limit_checker)
      program = Program.find_by(id: program_id)
      return if program.nil? || (!program.active?)
      previous_month = Time.current.prev_month
      time_range = ((previous_month.beginning_of_month)..(previous_month.end_of_month))
      options = {most_viewed_content_details: program.get_most_viewed_community_contents(time_range, MOST_VIEWED_CONTENT_COUNT).map{|hsh| {klass: hsh[:object].class.name, id: hsh[:object].id, role_id: hsh[:role_id]}}}
      selected_users = User.where(id: selected_user_ids)
      selected_users.each do |user|
        next unless user.digest_v2_required?
        delay(queue: DjQueues::WEEKLY_DIGEST).send_digest_v2_for_user(user.id, options)
      end
      delay(queue: DjQueues::WEEKLY_DIGEST).check_time_limit_exceeded(this_time_zone) if set_limit_checker
    end

    def send_digest_v2_for_user(user_id, options)
      user = User.includes(:pending_notifications, [connection_memberships: :pending_notifications]).find_by(id: user_id)
      return unless user
      return unless ChronusMailer.digest_v2(user, options).deliver_now
      time_stamp = Time.now
      if user.digest_v2_group_update_required?
        user.connection_memberships.each { |membership| membership.pending_notifications.destroy_all }
        user.update_column(:last_group_update_sent_time, time_stamp)
      end
      if user.digest_v2_program_update_required?
        user.pending_notifications.destroy_all
        user.update_column(:last_program_update_sent_time, time_stamp)
      end
    end

    def check_time_limit_exceeded(time_zone)
      time_in_time_zone = Time.now.in_time_zone(time_zone)
      Airbrake.notify("DigestV2Utils::Trigger : Emails are being sent till #{time_in_time_zone} [time zone is : '#{time_zone}']") if time_in_time_zone.hour >= EMAIL_SEND_LIMIT_HOUR
    end

    def get_valid_time_zones_at_this_time
      time_now = Time.now
      TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS.select do |time_zone|
        time_now.in_time_zone(time_zone).hour == TRIGGER_START_HOUR && time_now.in_time_zone(time_zone).min < 30
      end
    end

    def selected_user_ids_grouped_by_program(selected_time_zones)
      selected_time_zone_members_ids = Member.active.where(time_zone: selected_time_zones).pluck(:id)
      selected_time_zone_members_ids += Member.active.where(time_zone: nil).pluck(:id) if selected_time_zones.include?(TimezoneConstants::DEFAULT_TIMEZONE)
      selected_time_zone_user_details = User.active.where(member_id: selected_time_zone_members_ids).pluck(:id, :program_id)
      hsh = selected_time_zone_user_details.group_by{|ary| ary[1]}
      hsh.keys.each do |key|
        hsh[key].map!{ |ary| ary[0] }
      end
      hsh
    end
  end
end