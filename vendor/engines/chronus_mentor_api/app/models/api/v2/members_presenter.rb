class Api::V2::MembersPresenter < Api::V2::BasePresenter
  include Api::V2::BasicHelper

  PROFILE_QUESTIONS_METADATA = {
    "education" => {:multi_question_type => ProfileQuestion::Type::MULTI_EDUCATION, required_params: ["school_name"]},
    "experience" => {:multi_question_type => ProfileQuestion::Type::MULTI_EXPERIENCE, required_params: ["company"]},
    "publication" => {:multi_question_type => ProfileQuestion::Type::MULTI_PUBLICATION, required_params: ["title"]},
    "manager" => {required_params: ["first_name", "last_name", "email"]}
  }
  # get all program's members
  def list(params = {})
    member_ids, error = get_member_ids_created_after(params)
    return error if error.present?
    profile_answer_ids = nil
    profile_needed = params[:profile].to_i == 1
    if profile_needed
      member_ids, profile_answer_ids, error = get_member_and_profile_answer_ids(member_ids, params[:updated_after])
      return error if error.present?
    end
    members = Member.where(id: member_ids).includes(includes_list(profile_needed))
    list_members_hash(members, profile_answer_ids, {profile_needed: profile_needed, members_list: params[:members_list]}.merge(get_auth_options(members)))
  end

  # create a new member
  def create(params)
    result = {}
    errors = get_errors_for_create(params)
    return errors_hash(errors) unless errors.blank?
    member = Member.new
    copy_params_to_member_attributes_for_create(member, params)
    if member.save
      return success_hash({ uuid: member.id })
    else
      return errors_hash(member.errors.full_messages)
    end
  end

  def destroy(params)
    result = {}
    member = organization.members.find_by(id: params[:id])

    if member.present?
      unless member.can_be_removed_or_suspended?
        return errors_hash([ApiConstants::MemberErrors::OWNER_DESTROY_ERROR])
      end

      member.destroy
      result = success_hash( { uuid: member.id } )
    else
      result = member_not_found('uuid', params[:id])
    end
    return result
  end

  def update(params = {})
    result = {}
    member = organization.members.find_by(id: params[:id])
    if member.present?
      begin
        Member.transaction do
          member.assign_attributes(filter_member_params(params))
          member.build_login_identifiers_for_custom_auths(params[:login_name])

          if member.save
            profile_filed_errors = update_answers!(member, params[:profile]) if params.has_key?(:profile)
            raise profile_filed_errors.join(", ") if profile_filed_errors.present?
            result = success_hash(member_hash(member, profile_needed: true))
          else
            raise member.errors.full_messages.join(", ")
          end
        end
      rescue Exception => e
        result = errors_hash([e.message])
      end
    else
      result = member_not_found('uuid', params[:id])
    end
    return result
  end

  def update_status(params = {}, current_member = nil)
    result = {}
    member = organization.members.find_by(id: params[:uuid])
    errors = get_errors_for_member_update_status(params, member)
    return errors_hash(errors) unless errors.blank?

    case params[:status].to_i
    when Member::Status::ACTIVE
      member.reactivate!(current_member)
    when Member::Status::SUSPENDED
      member.suspend!(current_member, get_member_suspension_text, true)
    end
    return success_hash(member_hash(member))
  end

  def get_uuid(params = {})
    result =
      if params.has_key?(:email)
        get_member(:email, params[:email])
      elsif params.has_key?(:login_name)
        get_member(:login_name, params[:login_name])
      else
        errors_hash([ApiConstants::CommonErrors::ENTITY_NOT_PASSED % {entity: 'email or login_name'}])
      end
    return result
  end

  # find user by uuid
  def find(uuid, params = {})
    # member
    profile_needed = !params[:profile].present? || (1 == params[:profile].to_i)
    member = organization.members.where(id: uuid).includes(includes_list(profile_needed)).select(select_list).first
    # only if member exists
    if member.present?
      success_hash(member_hash(member, programs: true, profile_needed: profile_needed))
    else
      user_not_found_hash(uuid)
    end
  end

  protected

  def get_member(unique_identifier, value)
    member =
      if unique_identifier == :email
        organization.members.find_by(email: value)
      elsif unique_identifier == :login_name
        LoginIdentifier.find_by(auth_config_id: organization.get_and_cache_custom_auth_config_ids, identifier: value).try(:member)
      end

    member.present? ? success_hash(uuid: member.id) : member_not_found(unique_identifier, value)
  end

  def member_hash(member, options = {})
    res = {
      first_name: member.first_name,
      last_name:  member.last_name,
      email:      member.email,
      status:     member.state,
      uuid:       member.id,
      login_name: member.login_identifiers_for_custom_auths.first.try(:identifier) || ""
    }
    res[:programs] = get_program_details(member) if options[:programs]
    res.merge!(profile: profile_hash(member.profile_answers)) if options[:profile_needed]
    return res
  end

  def user_not_found_hash(uuid)
    errors_hash([ApiConstants::UserErrors::USER_NOT_FOUND % uuid.to_s])
  end

  def get_errors_for_create(params)
    errors = []
    errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: "first name" } unless params[:first_name]
    errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: "last name" } unless params[:last_name]
    errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: "email" } unless params[:email]
    errors << ApiConstants::MemberErrors::MEMBER_ALREADY_EXISTS % {value: params[:email]} if params[:email] && organization.members.find_by(email: params[:email])
    return errors
  end

  def get_errors_for_member_update_status(params, member)
    errors = get_errors_for_update_status(params, member)
    return errors unless errors.blank?
    errors = []
    if invalid_status_passed?(params[:status])
      errors << ApiConstants::MemberErrors::INVALID_STATUS_PASSED
    elsif member && !member.state_transition_allowed?(params[:status])
      errors << ApiConstants::MemberErrors::TRANSITION_NOT_POSSIBLE
    end
    return errors
  end

  def copy_params_to_member_attributes_for_create(member, params)
    member.first_name = params[:first_name]
    member.last_name = params[:last_name]
    member.email = params[:email]
    member.organization = self.organization
    member.state = Member::Status::DORMANT

    member.build_login_identifiers_for_custom_auths(params[:login_name])
  end

  def member_not_found(field, value)
    terms_hash = {entity: 'member', attribute: field, value: value}
    errors_hash([ApiConstants::CommonErrors::ENTITY_NOT_FOUND % terms_hash])
  end

  def get_program_details(member)
    res = {}
    member.users.each do |u|
      res.merge!({u.program.name => {
        status:  UsersHelper::STATE_TO_INTEGER_MAP[u.state],
        roles: get_role_details(u)
      }})
    end
    res
  end

  def get_role_details(u)
    res = []
    u.roles.each do |r|
      res += RolesMapping.aliased_names([r.name])
    end
    res
  end

  def check_required_params(params, keys)
    errors = []
    keys.each do |key|
      errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: key } if params[key].blank?
    end
    return errors
  end

  def validate_profile_params(key, answer, required_params, result_hash)
    errors = check_required_params(answer, required_params)
    if errors.present?
      result_hash[:valid] = false
      result_hash[:data] = errors
      return result_hash
    else
      result_hash[:data][key] = answer
    end
    return result_hash
  end

  def get_question_type(question)
    if question.education?
      return "education"
    elsif question.experience?
      return "experience"
    elsif question.publication?
      return "publication"
    elsif question.manager?
      return "manager"
    end
  end

  def validate_professional_question_params(question, answer)
    result = {valid: true, data: {}}
    question_type = get_question_type(question)
    return result if question_type.nil?
    required_params = PROFILE_QUESTIONS_METADATA[question_type][:required_params]
    multi_question_type = PROFILE_QUESTIONS_METADATA[question_type][:multi_question_type]
    if multi_question_type.present? && question.question_type == multi_question_type
      answer.each do |key, value|
        result = validate_profile_params(key, value, required_params, result)
      end
    else
      result = validate_profile_params("0", answer, required_params, result)
    end
    result[:data] = {"new_#{question_type}_attributes" => [result[:data]]} if result[:valid]
    return result
  end

  def update_answers!(member, answer_params)
    questions = member.organization.profile_questions.where(id: answer_params.keys)
    questions_to_update = questions.inject([]) do |resulting_array, question|
      resulting_array << [question, answer_params[question.id.to_s]] if question_can_be_updated?(question)
      resulting_array
    end
    questions_to_update.each do |question, answer|
      result = validate_professional_question_params(question, answer)
      return result[:data] if !result[:valid]
      if question.education?
        member.update_education_answers(question, result[:data])
      elsif question.experience?
        member.update_experience_answers(question, result[:data])
      elsif question.publication?
        member.update_publication_answers(question, result[:data])
      elsif question.manager?
        result[:data]["new_manager_attributes"] = result[:data]["new_manager_attributes"].map{|attrs| attrs.values}.flatten
        member.update_manager_answers(question, result[:data])
      else
        member.save_answer!(question, answer, from_import: true)
      end
    end
    member.users.each do |user|
      handle_profile_update(user, questions_to_update.collect{ |question_answer_array| question_answer_array[0].id })
    end
    return []
  end

  def invalid_status_passed?(status)
    status = status.to_i
    return status != Member::Status::ACTIVE && status != Member::Status::SUSPENDED
  end

  def no_user_attached_to_member?(member)
    return member && member.users.count == 0
  end


  def profile_hash(profile_answers)
    attributes = {}
    skype_enabled = organization.skype_enabled?
    profile_answers.each do |profile_answer|
      next if !skype_enabled && profile_answer.profile_question.question_type == ProfileQuestion::Type::SKYPE_ID
      profile_answer_value = case profile_answer.profile_question.question_type
      when ProfileQuestion::Type::FILE
         profile_answer.attachment_file_name
      when ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION
        educations_hash(profile_answer) if profile_answer.educations.present?
      when ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE
        experiences_hash(profile_answer)  if profile_answer.experiences.present?
      when ProfileQuestion::Type::PUBLICATION, ProfileQuestion::Type::MULTI_PUBLICATION
        publications_hash(profile_answer) if profile_answer.publications.present?
      when ProfileQuestion::Type::MANAGER
        managers_hash(profile_answer) if profile_answer.manager.present?
      when ProfileQuestion::Type::SINGLE_CHOICE, ProfileQuestion::Type::MULTI_CHOICE, ProfileQuestion::Type::ORDERED_OPTIONS, ProfileQuestion::Type::RATING_SCALE, ProfileQuestion::Type::ORDERED_SINGLE_CHOICE
        answer_value = profile_answer.answer_value
        answer_value.is_a?(Array) ? answer_value.join_by_separator(profile_answer.get_answer_seperator) : answer_value
      else
        profile_answer.answer_text
      end
      attributes.merge!(:"field_value_#{profile_answer.id}" => {
        field_id:   profile_answer.profile_question_id,
        field_name: profile_answer.profile_question.question_text,
        value:      profile_answer_value,
        applicable: profile_answer.not_applicable ? 0 : 1
      })
    end
    attributes
  end

  def education_hash(education)
    {
      school_name:     education.school_name,
      degree:          education.degree,
      major:           education.major,
      graduation_year: education.graduation_year
    }
  end

  def educations_hash(answer)
    answer.educations.inject({}) do |res, education|
      res.merge!(:"education_#{education.id}" => education_hash(education))
    end
  end

  def experience_hash(experience)
    {
      company:     experience.company,
      job_title:   experience.job_title,
      current_job: experience.current_job,
      start_month: experience.start_month,
      start_year:  experience.start_year,
      end_month:   experience.end_month,
      end_year:    experience.end_year
    }
  end

  def experiences_hash(answer)
    answer.experiences.inject({}) do |res, experience|
      res.merge!(:"experience_#{experience.id}" => experience_hash(experience))
    end
  end

  def publications_hash(profile_answer)
    profile_answer.publications.inject({}) do |res, publication|
      res.merge!(:"publication_#{publication.id}" => publication_hash(publication))
    end
  end

  def publication_hash(publication)
    {
      title:             publication.title,
      publisher:         publication.publisher,
      url:               publication.url,
      authors:           publication.authors,
      description:       publication.description,
      publication_day:   publication.day,
      publication_month: publication.month,
      publication_year:  publication.year
    }
  end

  def managers_hash(profile_answer)
    [profile_answer.manager].inject({}) do |res, manager|
      res.merge!(:"manager_#{manager.id}" => manager_hash(manager))
    end
  end

  def manager_hash(manager)
    {
      first_name:  manager.first_name,
      last_name:   manager.last_name,
      email:       manager.email
    }
  end

  def filter_member_params(params, with_uuid = true)
    attributes = {}
    attributes[:first_name] = params[:first_name] if params.has_key?(:first_name)
    attributes[:last_name]  = params[:last_name] if params.has_key?(:last_name)
    attributes[:email]      = params[:email] if params.has_key?(:email)
    attributes
  end

  def includes_list(profile_needed = true)
    list = []
    list << [ profile_answers: [ { profile_question: { question_choices: :translations } }, :educations, :experiences, :manager, :publications, :answer_choices ] ] if profile_needed
    list << [ users: [:roles, :program => :translations] ]
  end

  def select_list
    [:first_name, :last_name, :email, :state, :id, :organization_id]
  end

  def get_member_and_profile_answer_ids(member_ids, updated_after)
    updated_after, error = get_updated_after(updated_after)
    return [nil, nil, error] if error.present?

    updated_profile_answers = ProfileAnswer.where(ref_obj_type: Member.name, ref_obj_id: member_ids).
                                where("updated_at > ?", updated_after).
                                limit(ApiConstants::MAXIMUM_PROFILE_LIMIT + 1).
                                select(:id, :ref_obj_id)
    member_ids = updated_profile_answers.collect(&:ref_obj_id).uniq
    profile_answer_ids = updated_profile_answers.collect(&:id)

    if profile_answer_ids.count > ApiConstants::MAXIMUM_PROFILE_LIMIT
      return [nil, nil, errors_hash([ApiConstants::MemberErrors::MAXIMUM_PROFILE_LIMIT_EXCEEDED])]
    end
    [member_ids, profile_answer_ids, nil]
  end

  def list_members_hash(members, profile_answer_ids, options = {})
    custom_auth_id = options[:custom_auth_id]
    member_identifier_hash = options[:member_identifier_hash] if custom_auth_id

    # map received data to array
    members_array = Member.connection.
                    select_all(members.select("first_name, last_name, email, state as status, id as uuid")).
                    to_ary
    members = members.index_by(&:id)
    members_array.each do |member_hash|
      member = members[member_hash["uuid"]]
      member_hash["login_name"] = get_login_name(member_hash["uuid"], custom_auth_id, member_identifier_hash)
      member_hash["programs"] = get_program_details(member) if options[:members_list]
      if options[:profile_needed]
        member_hash["profile_updates"] = get_profile_updates_hash(member, profile_answer_ids)
      end
    end
    success_hash(members_array)
  end

  def get_login_name(member_id, custom_auth_id, member_identifier_hash)
    login_name = nil
    if custom_auth_id
      login_name = member_identifier_hash[member_id].try{ |login_identifiers| login_identifiers.first.identifier }
    end
    return login_name || ""
  end

  def get_auth_options(members)
    options = {}
    custom_auth_id = organization.auth_configs.select(&:custom?).first.try(:id)
    return options unless custom_auth_id

    options[:member_identifier_hash] = LoginIdentifier.
                                        where(auth_config_id: custom_auth_id, member_id: members.collect(&:id)).
                                        select(:identifier, :member_id).
                                        group_by(&:member_id)
    options[:custom_auth_id] = custom_auth_id
    options
  end

  def get_profile_updates_hash(member, profile_answer_ids)
    required_profile_answers = member.profile_answers.select{ |profile_answer| profile_answer.id.in?(profile_answer_ids) }
    profile_hash(required_profile_answers)
  end

  def build_members_query(params)
    members_query = {}
    members_query.merge!(email: params[:email]) if params.has_key?(:email)
    members_query.merge!(state: params[:status]) if params.has_key?(:status)
    members_query
  end

  def get_member_ids_created_after(params)
    members_query = build_members_query(params)
    members = organization.members.where(members_query)
    created_after = params[:created_after]

    return [members.pluck(:id), nil] unless created_after.present?

    created_after, error = get_created_after(created_after)
    return [nil, error] if error.present?

    member_ids = members.where("created_at > ?", created_after).pluck(:id)
    return [member_ids, nil]
  end

  def get_created_after(created_after)
    begin
      [created_after.to_datetime, nil]
    rescue => _ex
      [nil, errors_hash([ApiConstants::MemberErrors::INVALID_CREATED_AFTER_TIMESTAMP % { timestamp: created_after }])]
    end
  end

  def get_updated_after(updated_after)
    return [nil, errors_hash([ApiConstants::MemberErrors::UPDATED_AFTER_TIMESTAMP_MISSING])] unless updated_after.present?

    begin
      [updated_after.to_datetime, nil]
    rescue => _ex
      [nil, errors_hash([ApiConstants::MemberErrors::INVALID_UPDATED_AFTER_TIMESTAMP % { timestamp: updated_after }])]
    end
  end
end