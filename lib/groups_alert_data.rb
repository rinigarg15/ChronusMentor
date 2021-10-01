module GroupsAlertData

  def self.existing_groups_alert_data(program, student_ids_mentor_ids_array, non_active_group_status = nil)
    student_ids_mentor_ids_to_group_ids_map = {}
    group_id_name_map = {}
    group_id_status_map = {}

    group_statuses = Group::Status::ACTIVE_CRITERIA.dup
    group_statuses << non_active_group_status if non_active_group_status.present?

    select_list = "connection_memberships.group_id,
      groups.name AS group_name,
      groups.status AS group_status,
      GROUP_CONCAT(DISTINCT(connection_memberships.user_id) ORDER BY connection_memberships.user_id SEPARATOR ',') AS student_ids,
      GROUP_CONCAT(DISTINCT(mentor_memberships_groups.user_id) ORDER BY mentor_memberships_groups.user_id SEPARATOR ',') AS mentor_ids"

    student_ids_mentor_ids_array.each do |student_ids_mentor_ids|
      student_ids, mentor_ids = student_ids_mentor_ids

      query = Connection::MenteeMembership.
        select(select_list).
        joins(group: :mentor_memberships).
        where(user_id: student_ids).
        where(groups: { status: group_statuses } ).
        where(mentor_memberships_groups: { user_id: mentor_ids } ).
        group("connection_memberships.group_id")

      self.query_results_for_existing_groups_alert(query, student_ids_mentor_ids_to_group_ids_map, group_id_name_map, group_id_status_map)
    end
    user_id_name_map = self.get_user_id_map(program, student_ids_mentor_ids_to_group_ids_map.keys.flatten)[0]
    [student_ids_mentor_ids_to_group_ids_map, group_id_name_map, group_id_status_map, user_id_name_map]
  end

  def self.bulk_match_additional_users_alert_data(program, drafted_group_ids)
    student_id_mentor_id_to_additional_users_map = {}

    includes_list = [:memberships, :student_memberships, :mentor_memberships]
    bulk_match_ids = program.bulk_matches.pluck(:id)
    drafted_groups = program.groups.drafted.
      where(bulk_match_id: bulk_match_ids).
      where(id: drafted_group_ids).
      includes(includes_list)

    drafted_groups.each do |drafted_group|
      memberships = drafted_group.memberships
      if memberships.size > 2
        student_id_mentor_id = drafted_group.initial_student_mentor_pair
        student_id_mentor_id_to_additional_users_map[student_id_mentor_id] = memberships.collect(&:user_id).sort - student_id_mentor_id
      end
    end

    user_id_name_map, user_id_member_id_map = self.get_user_id_map(program, student_id_mentor_id_to_additional_users_map.to_a.flatten)
    [student_id_mentor_id_to_additional_users_map, user_id_name_map, user_id_member_id_map]
  end

  def self.multiple_existing_groups_note_data(program)
    query = Connection::MenteeMembership.
      where(user_id: program.all_user_ids).
      select("connection_memberships.user_id as student_id, mentor_memberships_groups.user_id as mentor_id, groups.name as group_name, groups.id as group_id").
      joins(group: :mentor_memberships).
      where(groups: { status: Group::Status::ACTIVE_CRITERIA } )

    student_id_mentor_id_to_group_ids_map, group_id_name_map = self.query_results_for_multiple_existing_groups_note(query)
    student_id_mentor_id_to_group_ids_map.keep_if { |_, group_ids| group_ids.size > 1 }
    group_id_name_map.slice!(*student_id_mentor_id_to_group_ids_map.values.flatten)
    user_id_name_map = self.get_user_id_map(program, student_id_mentor_id_to_group_ids_map.keys.flatten)[0]
    [student_id_mentor_id_to_group_ids_map, group_id_name_map, user_id_name_map]
  end

  private

  def self.get_user_id_map(program, user_ids)
    user_id_name_map = {}
    user_id_member_id_map = {}

    users = program.all_users.where(id: user_ids).includes(:member)
    users.each do |user|
      user_id_name_map[user.id] = user.name(name_only: true)
      user_id_member_id_map[user.id] = user.member_id
    end
    [user_id_name_map, user_id_member_id_map]
  end

  def self.query_results_for_existing_groups_alert(query, student_ids_mentor_ids_to_group_ids_map, group_id_name_map, group_id_status_map)
    results = ActiveRecord::Base.connection.select_all(query)
    results.each do |result|
      result_student_ids = result["student_ids"].split(",").map(&:to_i)
      result_mentor_ids = result["mentor_ids"].split(",").map(&:to_i)
      result_group_id = result["group_id"].to_i

      key = [result_student_ids, result_mentor_ids]
      student_ids_mentor_ids_to_group_ids_map[key] ||= []
      student_ids_mentor_ids_to_group_ids_map[key] |= [result_group_id]
      group_id_name_map[result_group_id] ||= result["group_name"]
      group_id_status_map[result_group_id] ||= result["group_status"].to_i
    end
  end

  def self.query_results_for_multiple_existing_groups_note(query)
    student_id_mentor_id_to_group_ids_map = {}
    group_id_name_map = {}

    results = ActiveRecord::Base.connection.select_all(query)
    results.each do |result|
      student_id = result["student_id"].to_i
      mentor_id = result["mentor_id"].to_i
      group_id = result["group_id"].to_i

      key = [student_id, mentor_id]
      student_id_mentor_id_to_group_ids_map[key] ||= []
      student_id_mentor_id_to_group_ids_map[key] << group_id
      group_id_name_map[group_id] = result["group_name"]
    end
    [student_id_mentor_id_to_group_ids_map, group_id_name_map]
  end
end