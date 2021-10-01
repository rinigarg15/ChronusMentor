class Api::V2::ConnectionsPresenter < Api::V2::BasePresenter
  # status mapping
  module Status
    DRAFTED  = 0
    ACTIVE   = 1
    CLOSED   = 2
    INACTIVE = 3
    def self.group_states
      {
        DRAFTED  => Group::Status::DRAFTED,
        ACTIVE   => Group::Status::ACTIVE,
        CLOSED   => Group::Status::CLOSED,
        INACTIVE => Group::Status::INACTIVE,
      }
    end
    def self.from_group_state(state)
      (state && group_states.invert[state.to_i]) || ACTIVE
    end

    def self.to_group_state(state)
      (state && group_states[state.to_i]) || Group::Status::ACTIVE
    end
  end

  # get all program's groups
  def list(params = {})
    connections_chain = program.groups.includes(:students, :mentors)
    # add filter by email
    if params.has_key?(:email)
      connections_chain = connections_chain.
        joins(students: :member).
        joins(mentors: :member).
        where("members.email=? OR members_users.email=?", *([params[:email]] * 2))
    end
    # add filter by status
    if params.has_key?(:state)
      connections_chain = connections_chain.where(status: Status.to_group_state(params[:state]))
    end
    # map received data to array
    success_hash(connections_chain.map { |connection| base_connection_hash(connection) })
  end

  # get group by id
  def find(group_id, params = {})
    connections_chain = program.groups.includes(:students, :mentors).where(id: group_id)
    # include answers if needed
    if need_profile = (1 == params[:profile].to_i)
      connections_chain = connections_chain.includes(:answers)
    end
    # ACTIVITIES LISTING DISABLED FOR NOW
    # include answers if activities
    # if need_activities = (1 == params[:activity_report].to_i)
    #   connections_chain = connections_chain.includes(:activities)
    # end
    # only if group exists
    if connections_chain.exists?
      connection = connections_chain.first
      connection_hash = full_connection_hash(connection)
      connection_hash.merge!(answers_hash(connection)) if need_profile
      # ACTIVITIES LISTING DISABLED FOR NOW
      # connection_hash.merge!(activities_hash(connection)) if need_activities
      # return
      success_hash(connection_hash)
    else
      group_not_found_hash(group_id)
    end
  end

  # create new connection by given params
  def create(params)
    mentors, students, errors = collect_mentors_and_mentees(params[:mentor_email], params[:mentee_email])
    if errors.empty?
      build_params = filter_group_params(params, mentors, students, {from_create: true})
      # check for errors
      if build_params.has_key?(:errors)
        errors_hash(build_params[:errors])
      else
        connection = program.groups.build(build_params)
        # ok
        if connection.save
          success_hash({ id: connection.id, mentor_ids: mentors.collect(&:member_id), student_ids: students.collect(&:member_id) })
        # failed
        else
          errors_hash(connection.errors.full_messages)
        end
      end
    else
      errors_hash(errors)
    end
  end

  # change existing connection
  def update(group_id, params)
    connections_chain = program.groups.where(id: group_id)
    # if found
    if connections_chain.exists?
      connection = connections_chain.first
      mentors, students, errors = collect_mentors_and_mentees(params[:mentor_email], params[:mentee_email])
      if errors.empty?
        if update_connection(connection, mentors, students, params)
          success_hash(full_connection_hash(connection.reload))
        # failed
        else
          errors_hash(connection.errors.full_messages)
        end
      else
        errors_hash(errors)
      end
    # not found
    else
      group_not_found_hash(group_id)
    end
  end

  # destroy connection
  def destroy(group_id)
    connections_chain = program.groups.where(id: group_id)
    # if found
    if connections_chain.exists?
      connection = connections_chain.first
      connection.destroy
      success_hash({ id: connection.id })
    # not found
    else
      group_not_found_hash(group_id)
    end
  end

protected
  def group_not_found_hash(group_id)
    errors_hash([ApiConstants::ConnectionErrors::CONNECTION_NOT_FOUND % group_id.to_s])
  end

  def activities_hash(connection)
    {
      activities: connection.activities.map { |a|
        { action_type: a.action_type, target: a.target, message: a.message }
      }
    }
  end

  def answers_hash(connection)
    {
      profiles: connection.answers.includes(:answer_choices, common_question: {question_choices: :translations}).map { |a|
        { id: a.common_question_id, answer: get_answer_text(a) }
      }
    }
  end

  def update_connection(connection, mentors, students, params)
    Group.transaction do
      # try to update answers list
      if connection.update_answers(params.delete(:profile) || {}, true)
        build_params = filter_group_params(params, mentors, students, closure_reason_id: connection.get_auto_terminate_reason_id)
        # check for errors
        if build_params.has_key?(:errors)
          build_params[:errors].each do |param_error|
            connection.errors.add(:base, param_error)
          end
          false
        else
          connection.update_attributes(build_params)
        end
      end
    end
  end

  def filter_group_params(params, mentors, students, options = {})
    attributes = {}
    attributes[:mentor_ids]  = mentors.map(&:id) if mentors.any?
    attributes[:student_ids] = students.map(&:id) if students.any?
    attributes[:name]        = params[:name] if params.has_key?(:name)
    attributes[:notes]       = params[:note] if params.has_key?(:note)
    if params.has_key?(:template_id) && options[:from_create]
      if program.mentoring_models.find_by(id: params[:template_id].to_i).present?
        attributes[:mentoring_model_id] = params[:template_id]
      else
        attributes[:errors] = [ApiConstants::ConnectionErrors::TEMPLATE_ID_NOT_FOUND % params[:template_id]]
      end
    end
    # try to parse date
    if params.has_key?(:expiry_date)
      begin
        attributes[:expiry_time] = DateTime.parse(params[:expiry_date])
      rescue
        attributes[:errors] = [ApiConstants::ConnectionErrors::EXPIRE_DATE_FORMAT]
      end
    end
    case attributes[:status] = Status.to_group_state(params[:status])
    when Group::Status::ACTIVE
      attributes[:actor] = params[:acting_user]
    when Group::Status::DRAFTED
      attributes[:created_by] = params[:acting_user]
    when Group::Status::CLOSED
      if params[:termination_reason].present?
        attributes[:termination_reason] = params[:termination_reason]
        attributes[:closed_by]          = params[:acting_user]
        attributes[:closed_at]          = Time.now
        attributes[:termination_mode]   = Group::TerminationMode::ADMIN
        attributes[:closure_reason_id]   = options[:closure_reason_id]
      else
        attributes[:errors] = [ApiConstants::ConnectionErrors::TERMINATION_REASON_IS_BLANK]
      end
    end
    attributes
  end

  def collect_mentors_and_mentees(mentor_emails, mentee_emails)
    errors = []
    # mentors by emails
    mentors, mentor_errors = collect_users_by_emails(mentor_emails)
    errors += mentor_errors
    # mentees by emails
    students, student_errors = collect_users_by_emails(mentee_emails)
    errors += student_errors
    [mentors, students, errors]
  end

  def collect_users_by_emails(emails_str)
    users, errors = [], []
    emails_str.to_s.split(",").each do |email|
      m = User.find_by_email_program(email, program)
      if m.present?
        users << m
      else
        errors << ApiConstants::ConnectionErrors::USER_NOT_FOUND % email
      end
    end
    [users, errors]
  end

  def full_connection_hash(connection)
    base_connection_hash(connection).merge({
      state:            Status.from_group_state(connection.status),
      closed_on:        datetime_to_string(connection.closed_at),
      notes:            connection.notes,
      last_activity_on: datetime_to_string(connection.last_activity_at),
    })
  end


  def base_connection_hash(connection)
    {
      id: connection.id,
      name: connection.name,
      mentors: connection.mentors.map { |m|
        {
          id: m.member_id,
          name: m.name,
          connected_at: datetime_to_string(m.created_at),
        }
      },
      mentees: connection.students.map { |m|
        {
          id: m.member_id,
          name: m.name,
          connected_at: datetime_to_string(m.created_at),
        }
      }
    }
  end

  def datetime_to_string(t)
    t && t.strftime("%Y-%m-%d")
  end

  def get_answer_text(answer)
    if(answer.common_question.choice_or_select_type?)
      answer.selected_choices_to_str
    else
      answer.answer_text
    end
  end
end
