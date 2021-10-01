class Api::V2::UsersPresenter < Api::V2::BasePresenter
  include Api::V2::BasicHelper
  # get all program's users
  def list(params = {})
    result = { success: true }
    # users
    errors = check_for_list_user_errors(program, params)
    return errors_hash(errors) if errors.present?
    users_chain = program.users.includes(:member)

    # add filter by email
    users_chain = users_chain.where(members: { email: params[:email] }) if params.has_key?(:email)
    users_chain = filter_users_by_roles(program, users_chain, RolesMapping.roles_from_aliases(params[:roles])) if params.has_key?(:roles)
    users_chain = filter_users_by_status(users_chain, params[:status].to_i) if params.has_key?(:status)

    # check if everything is ok
    # map received data to array
    result = success_hash(users_chain.map { |user| user_hash(user) })
    return result
  end

  # create user
  def create(params)
    result = {}
    errors = []
    if params[:email].blank? && params[:uuid].blank?
      errors << ApiConstants::UserErrors::EMAIL_NOT_PASSED
      return errors_hash(errors)
    elsif params[:uuid].present?
      member = organization.members.find_by(id: params[:uuid])
      return user_not_found_hash(params[:uuid]) if member.nil?
    elsif params[:email].present?
      member = organization.members.find_by(email: params[:email])
    end
    return errors_hash([ApiConstants::UserErrors::INCORRECT_ROLES]) unless (roles = RolesMapping.get_valid_roles(program, RolesMapping.roles_from_aliases(params[:roles]))).present?
    Member.transaction do
      # find member
      unless (member_present = !member.nil?)
        # filter build params
        build_params = filter_member_params(params)
        # build member
        member = organization.members.build(build_params.except(:login_name))
        member.build_login_identifiers_for_custom_auths(build_params[:login_name])
        member_present = member.save
      end
      # check if member valid
      result = if member_present
        # create user
        begin
          attributes = params[:send_invite].to_i.zero? ? {} : { created_by: params[:acting_user] }
          user = program.build_and_save_user!(attributes, roles, member)
          # ok
          success_hash({ uuid: member.id })
        rescue
          errors_hash(user.errors.full_messages)
        end
      # pass errors
      else
        errors_hash(member.errors.full_messages)
      end
    end
    result
  end

  def update_status(params = {}, current_member = nil)
    result = {}
    member = organization.members.find_by(id: params[:uuid])
    user = member.user_in_program(program) if member.present?
    errors = get_errors_for_user_update_status(params, member, user)
    return errors_hash(errors) if errors.present?

    current_user = current_member.user_in_program(program)
    case UsersHelper::STATE_INTEGER_TO_STRING_MAP[params[:status].to_i]
    when user.state
    when User::Status::ACTIVE
      user.suspended? ? user.reactivate_in_program!(current_user) : user.publish_profile!(current_user)
    when User::Status::SUSPENDED
      user.suspend_from_program!(current_user, get_member_suspension_text)
    end
    return success_hash(user_hash(user))
  end

  # destroy user found by uuid
  def destroy(uuid)
    user = program.users.find_by(member_id: uuid)
    if user.present?
      unless user.can_be_removed_or_suspended?
        return errors_hash([ApiConstants::UserErrors::DESTROY_ERROR])
      end
      user.destroy
      success_hash( { uuid: user.member_id } )
    else
      user_not_found_hash(uuid)
    end
  end

  protected

   def get_errors_for_user_update_status(params, member, user)
    errors = get_errors_for_update_status(params, member)
    return errors if errors.present?

    errors = []
    status = UsersHelper::STATE_INTEGER_TO_STRING_MAP[params[:status].to_i]
    if user.nil?
      errors << ApiConstants::UserErrors::USER_NOT_PART_OF_PROGRAM % { value: params[:uuid], program_term: organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).term_downcase }
    end
    if User::Status.allowed_in_api.exclude?(status)
      errors << ApiConstants::MemberErrors::INVALID_STATUS_PASSED
    elsif user && !user.state_transition_allowed_in_api?(status)
      errors << ApiConstants::MemberErrors::TRANSITION_NOT_POSSIBLE
    end
    return errors
  end

  def filter_users_by_roles(program, users_chain, roles)
    roles = RolesMapping.get_valid_roles(program, roles)
    users_chain = users_chain.for_role(roles)
  end

  def filter_users_by_status(users_chain, status)
    status = UsersHelper::STATE_INTEGER_TO_STRING_MAP[status]
    users_chain = users_chain.where(state: status)
  end

  def update_answers(user, answer_params)
    questions = user.member.organization.profile_questions.where(id: answer_params.keys).includes(question_choices: :translations)
    questions_to_update = questions.inject([]) do |resulting_array, question|
      resulting_array << [question, answer_params[question.id.to_s]] if question_can_be_updated?(question)
      resulting_array
    end
    questions_to_update.each do |question, answer|
      user.save_answer!(question, answer, false, from_import: true)
      handle_profile_update(user, questions_to_update.collect{ |question_answer_array| question_answer_array[0].id })
    end
  end

  def filter_member_params(params)
    attributes = {}
    attributes[:first_name] = params[:first_name] if params.has_key?(:first_name)
    attributes[:last_name]  = params[:last_name] if params.has_key?(:last_name)
    attributes[:email]      = params[:email] if params.has_key?(:email)
    attributes[:login_name] = params[:login_name] if params.has_key?(:login_name)
    attributes
  end

  def user_not_found_hash(uuid)
    errors_hash([ApiConstants::UserErrors::USER_NOT_FOUND % uuid.to_s])
  end

  def check_for_list_user_errors(program, params)
    errors = []
    errors << ApiConstants::UserErrors::INCORRECT_ROLES if params.has_key?(:roles) && RolesMapping.get_valid_roles(program, RolesMapping.roles_from_aliases(params[:roles])).blank?
    errors << ApiConstants::UserErrors::INCORRECT_STATUS if params.has_key?(:status) && UsersHelper::STATE_INTEGER_TO_STRING_MAP[params[:status].to_i].nil?
    return errors
  end
end
