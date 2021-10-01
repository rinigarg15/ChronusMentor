module Api::V2::BasicHelper

  NOT_UPDATEABLE_QUESTION_TYPE = [
    ProfileQuestion::Type::FILE
  ]

  def question_can_be_updated?(profile_question)
    not_updatable_questions = NOT_UPDATEABLE_QUESTION_TYPE
    not_updatable_questions << ProfileQuestion::Type::SKYPE_ID if !(profile_question.organization.skype_enabled?)
    !not_updatable_questions.include?(profile_question.question_type)
  end
  
  def handle_profile_update(user, profile_question_ids = [])
    Matching.perform_users_delta_index_and_refresh_later([user.id], user.program, profile_question_ids: profile_question_ids)
    user.set_last_profile_update_time
    if user.profile_incomplete_roles.empty? && user.profile_pending?
      user.update_attribute(:state, User::Status::ACTIVE)
    end
  end

  def user_hash(user, profile_needed = false)
    res = {
      first_name: user.first_name,
      last_name:  user.last_name,
      email:      user.email,
      status:     UsersHelper::STATE_TO_INTEGER_MAP[user.state],
      uuid:       user.member.id,
      roles:      Api::V2::BasePresenter::RolesMapping.aliased_names(user.role_names)
    }
    res.merge!(profile: profile_hash(user)) if profile_needed
    res
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


  def profile_hash(user)
    attributes = {}
    user.profile_answers.includes({profile_question: {question_choices: :translations}}, :educations, :experiences, :answer_choices).each do |profile_answer|
      profile_answer_value = case profile_answer.profile_question.question_type
      when ProfileQuestion::Type::FILE
         profile_answer.attachment_file_name
      when ProfileQuestion::Type::EDUCATION, ProfileQuestion::Type::MULTI_EDUCATION
        educations_hash(profile_answer)
      when ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE
        experiences_hash(profile_answer)
      else
        profile_answer.answer_value
      end
      attributes.merge!(:"field_value_#{profile_answer.id}" => {
        field_id:   profile_answer.profile_question_id,
        field_name: profile_answer.profile_question.question_text,
        value:      profile_answer_value
      })
    end
    attributes
  end

  
  def get_member_suspension_text
    return "feature.user.content.status.suspension_through_api".translate(admin: @organization.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term_downcase) 
  end

  def get_errors_for_update_status(params, member)
    errors = []
    errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: "uuid" } unless params[:uuid]
    errors << ApiConstants::CommonErrors::ENTITY_NOT_PASSED % { entity: "status" } unless params[:status]
    errors << ApiConstants::MemberErrors::MEMBER_DOES_NOT_EXISTS % {value: params[:uuid]} if params[:uuid] && member.nil?
    return errors
  end


end