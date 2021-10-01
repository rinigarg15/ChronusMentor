class MobileApi::V1::GroupsPresenter < MobileApi::V1::BasePresenter
  include MentoringModelUtils

  # get group by id
  def find(group_id, acting_user)
    group = acting_user.groups.published.find(group_id)
    connection_hash = full_connection_hash(group, acting_user)
    [group, success_hash(connection_hash)]
  end

protected

  def full_connection_hash(connection, acting_user = nil)
    full_hash = base_connection_hash(connection, acting_user)
    full_hash.merge({
      state:            connection.status,
      closed_on:        datetime_to_string(connection.closed_at),
      notes:            connection.notes,
      last_activity_on: datetime_to_string(connection.last_activity_at)
    })
  end


  def base_connection_hash(connection, acting_user, options = {})
    {
      id: connection.id,
      name: connection.name,
      logo_file_name:   connection.logo_file_name,
      last_activity_on: datetime_to_string(connection.last_activity_at),
      tasks: tasks_meta_dictionary(connection),
      image_url: generate_connection_url(connection, acting_user, size: :medium),
      ## TODO:: This will not scale for multiple roles, PBE scenarios
      mentors: connection.mentors.includes(connection_user_includes).map { |mentor|
        {
          id: mentor.id,
          name: mentor.name,
          connected_at: datetime_to_string(mentor.created_at),
          image_url: generate_member_url(mentor.member, size: :medium)
        }
      },
      mentees: connection.students.includes(connection_user_includes).map { |mentee|
        {
          id: mentee.id,
          name: mentee.name,
          connected_at: datetime_to_string(mentee.created_at),
          image_url: generate_member_url(mentee.member, size: :medium)
        }
      }
    }
  end

private

  def connection_user_includes
    {
      member: :profile_picture
    }
  end
end