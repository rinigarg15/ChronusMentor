class ManagerObserver < ActiveRecord::Observer
  def before_validation(manager)
    if manager.email_changed? && manager.profile_answer.ref_obj_type == "Member"
      manager.update_member_id
    end
  end

  def after_save(manager)
    # Avoid calling it when we are changing just the member_id
    if (manager.saved_change_to_email? || manager.saved_change_to_first_name? || manager.saved_change_to_last_name?)
      answer = manager.profile_answer.reload
      answer.answer_value = manager.full_data
      answer.save
    end
    managee = manager.managee
    ManagerObserver.delay.handle_profile_update(managee.id, manager.profile_answer.profile_question_id) if manager.saved_change_to_member_id? && managee.prevent_matching_enabled?
  end

  def before_destroy(manager)
    managee = manager.managee
    #TODO-PERF: When a manager question is removed, destroying a lot of managers, hence many calls to this function
    ManagerObserver.delay.handle_profile_update(managee.id, manager.profile_answer.profile_question_id, true) if managee.prevent_matching_enabled?
  end

  def after_destroy(manager)
    answer = manager.profile_answer.reload
    answer.answer_value = []
    answer.save
  end

  def self.handle_profile_update(member_id, profile_question_id, managee_destroyed = false)
    member = Member.where(:id => member_id)
    members = managee_destroyed ? [] : member
    members += self.managee_tree(member)
    self.perform_delta_index(members, profile_question_id)
  end

  private

  def self.perform_delta_index(members, profile_question_id)
    members.collect(&:users).flatten.each do |user|
      Matching.perform_users_delta_index_and_refresh_later([user.id], user.program, profile_question_ids: [profile_question_id])
    end
  end

  def self.managee_tree(members)
    self.managee_tree_rec(members, [], members.first.prevent_manager_matching_level, 0)
  end

  def self.managee_tree_rec(members, child_array, max_level, cur_level)
    return child_array if members.nil? || max_level == cur_level
    managees = members.collect(&:managees).flatten
    return child_array if managees.empty?
    managees = managees - (child_array & managees)
    child_array+=managees
    self.managee_tree_rec(Member.includes(:managees, :users).where(:id => managees),child_array, max_level, cur_level+1)
  end

end