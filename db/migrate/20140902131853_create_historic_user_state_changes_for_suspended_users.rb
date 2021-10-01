class CreateHistoricUserStateChangesForSuspendedUsers< ActiveRecord::Migration[4.2]
  def up
    add_column :user_state_changes, :date_time, :datetime
    UserStateChange.reset_column_information
    return unless UserStateChange.any?
    user_state_change_objects = []
    @original_migration_run_time = UserStateChange.first.created_at
    suspension_ras = RecentActivity.where(:action_type => RecentActivityConstants::Type::USER_SUSPENSION).select([:ref_obj_id, :created_at])
    UserStateChange.includes(:user => [:connection_memberships, :posts, :qa_questions, :qa_answers, :comments, :state_transitions]).each do |usc|
      next unless (usc.from_state == nil && usc.to_state == User::Status::SUSPENDED)
      user = usc.user
      state_updated_later = user.state_transitions.size > 1
      last_seen_at = user.last_seen_at
      state_before_suspension = last_seen_at.present? ? User::Status::ACTIVE : User::Status::PENDING
      # ra is not created when user is suspended via bulk actions and some other cases
      last_suspended_at = get_time_of_last_activity(suspension_ras.select{|ra| ra.ref_obj_id == usc.user_id})
      last_connection_membership_created_at = get_time_of_last_activity(user.connection_memberships)
      last_post_created_at = get_time_of_last_activity(user.posts)
      last_qa_question_created_at = get_time_of_last_activity(user.qa_questions)
      last_qa_answer_created_at = get_time_of_last_activity(user.qa_answers)
      last_comment_created_at = get_time_of_last_activity(user.comments)

      last_activities = []
      last_activities << last_seen_at if last_seen_at && !state_updated_later
      last_activities << last_suspended_at if last_suspended_at
      last_activities << last_connection_membership_created_at if last_connection_membership_created_at
      last_activities << last_post_created_at if last_post_created_at
      last_activities << last_qa_question_created_at if last_qa_question_created_at
      last_activities << last_qa_answer_created_at if last_qa_answer_created_at
      last_activities << last_comment_created_at if last_comment_created_at
      last_activities << user.created_at

      # Adding 1 minute buffer as it is unlikely that the user is suspended at the exact same time as his last activity
      last_activity_time = last_activities.max + 1.minute
      
      info = usc.info_hash
      info[:state][:to] = state_before_suspension
      usc.set_info(info)
      user_state_change_objects << usc
      new_usc = user.state_transitions.new(date_id: get_date_id(last_activity_time), date_time: last_activity_time)
      info[:state][:from] = state_before_suspension
      info[:state][:to] = User::Status::SUSPENDED
      info[:role][:from] = info[:role][:to]
      new_usc.set_info(info)
      user_state_change_objects << new_usc
    end
    UserStateChange.import user_state_change_objects, on_duplicate_key_update: [:info], validate: false
  end

  def down
    remove_column :user_state_changes, :date_time
  end

  private

  def get_time_of_last_activity(activities)
    # Last activity created before the user state change migration was run
    activities.collect(&:created_at).select{|t| t < @original_migration_run_time}.max
  end

  def get_date_id(timestamp)
    (timestamp.utc.to_i/86400)
  end
end
