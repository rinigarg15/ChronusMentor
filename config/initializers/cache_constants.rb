module CacheConstants
  module Programs
    BANNER = Proc.new{|org_prog_id, locale| "#{locale}_program_banner_#{org_prog_id}"}
    THEME_STYLESHEET = Proc.new{|org_prog_id| "program_theme_stylesheet_#{org_prog_id}"}

    # This is expired in questions_controller after filter
    USER_FILTERS = Proc.new{|program_id, role| "#{I18n.locale}_users_filter_pane_#{program_id}_#{role}"}
  end

  module Groups
    # This is not being expired
    SUMMARY_PANE = Proc.new{|group_id, user_id, mentors_size, students_size, custom_users_size, owner_ids, last_last_seen_at| "#{I18n.locale}_summary_pane_#{group_id}_#{user_id}_#{mentors_size}_#{students_size}_#{custom_users_size}_#{owner_ids}_#{last_last_seen_at}"}
  end

  module Members
    # The following is expired in members controller after_filters
    PROFILE_SUMMARY_FIELDS = Proc.new{|user_id, role, viewer_role, time_stamp| "#{I18n.locale}_profile_summary_fields_#{user_id}_#{role}_#{viewer_role}_#{time_stamp}"}
  end

end
