class SurveyResponsesDataService
  DEFAULT_PAGE_SIZE = 10
  DEFAULT_SORT_ORDER = "asc"
  DEFAULT_SORT_PARAM = "date"

  module Operators
    CONTAINS = "eq"
    NOT_CONTAINS = "not_eq"
    FILLED = "answered"
    NOT_FILLED = "not_answered"
    DATE_TYPE = "date_type"
  end

  attr_reader :user_ids, :filters_count

  def initialize(survey, options)
    @survey = survey
    @options = options
    @profile_questions = @survey.profile_questions_to_display
    @user_ids = nil
    get_filtered_response_ids(options[:response_ids])
  end

  def responses_hash
    @responses_hash
  end

  def total_count
    response_ids.size
  end

  def response_ids
    @response_ids
  end

  def sorted_response_ids
    compute_responses_hash
    @response_ids = SortResponses.new(@survey, @response_by_user_hash, @responses_hash, @options).apply_sort if @response_ids.present?
    @response_ids
  end

  def get_page_data
    page = @options[:page] || 1
    per_page = (@options["pageSize"] || DEFAULT_PAGE_SIZE).to_i

    keys = sorted_response_ids.paginate(page: page, per_page: per_page)
    populate_response_hash_with_data(keys)
    return responses_hash.slice(*keys)
  end

  private

  def get_filtered_response_ids(response_ids)
    @response_ids, @user_ids, @filters_count =
      if response_ids.present?
        [response_ids, @survey.program.all_user_ids, 0]
      else
        FilterResponses.new(@survey, @options).apply_filters
      end
 end

  def compute_responses_hash
    @responses_hash = @response_ids.inject({}) { |hash, val| hash[val] = {}; hash }
    @response_by_user_hash = @survey.survey_answers.where(response_id: @response_ids).select(:response_id, :user_id).group_by(&:user_id)
  end

  def populate_response_hash_with_data(response_ids)
    survey_answers_iterator(response_ids) do |response_id, answers, user|
      @responses_hash[response_id][:user] = user
      if @survey.engagement_survey?
        @responses_hash[response_id][:group] = answers.first.group
        @responses_hash[response_id][:connection_role_id] = answers.first.connection_membership_role_id
      else

      end
      if @survey.meeting_feedback_survey?
        @responses_hash[response_id][:meeting_name] = answers.first.member_meeting.get_meeting.topic
        @responses_hash[response_id][:meeting] = answers.first.member_meeting.get_meeting
      end
      @responses_hash[response_id][:date] = answers.first.last_answered_at
      @responses_hash[response_id][:answers] = get_all_survey_answers_in_hash(answers)

      @responses_hash[response_id][:profile_answers] =  @profile_questions.present? ? get_all_profile_answers_hash_for_user(user) : {}
    end
  end

  def survey_answers_iterator(response_ids, &block)
    @survey.survey_answers.where(response_id: response_ids).includes([{user: :member}, {survey_question: [{question_choices: :translations}, matrix_question: {question_choices: :translations}]}, :answer_choices]).group_by(&:response_id).each do |response_id, answers|
      next unless answers.any?
      user = answers.first.user
      block.call(response_id, answers, user)
    end
  end

  def get_all_profile_answers_hash_for_user(user)
    profile_answers_hash = {}
    profile_answers_by_question_id = user.member.profile_answers.includes({profile_question: [question_choices: :translations]}, :answer_choices).answered.where(profile_answers: {profile_question_id: @profile_questions.collect(&:id)}).group_by(&:profile_question_id)
    @profile_questions.each do |profile_question|
      if profile_question.choice_or_select_type? || profile_question.date?
        profile_answers_hash[profile_question.id] = profile_question.format_profile_answer(profile_answers_by_question_id[profile_question.id].first) if profile_answers_by_question_id[profile_question.id].present?
      else
        profile_answers_hash[profile_question.id] = profile_answers_by_question_id[profile_question.id].first.answer_text if profile_answers_by_question_id[profile_question.id].present?
      end
    end
    profile_answers_hash
  end

  def get_all_survey_answers_in_hash(answers)
    response_answer_hash = {}
    answers.each do |ans|
      if ans.survey_question.choice_or_select_type?
        response_answer_hash[ans.common_question_id] = ans.selected_choices_to_str(ans.survey_question)
      else
        response_answer_hash[ans.common_question_id] = ans.answer_text
      end
    end
    response_answer_hash
  end

  class SortResponses

    def initialize(survey, response_by_user_hash, responses_hash, options)
      @survey = survey
      @options = options
      @response_by_user_hash = response_by_user_hash
      @responses_hash = responses_hash
    end

    def apply_sort
      sort_param = @options[:sort].present? ? @options[:sort].values.first["field"] : DEFAULT_SORT_PARAM
      sort_order = @options[:sort].present? ? @options[:sort].values.first["dir"] : DEFAULT_SORT_ORDER
      if sort_param == SurveyResponseColumn::Columns::SenderName
        sort_based_on_user_details("name_only.sort", sort_order)
      elsif sort_param == "date"
        sort_based_on_survey_response_date(sort_order)
      elsif sort_param == SurveyResponseColumn::Columns::Roles
        sort_based_on_user_roles(sort_order)
      elsif sort_param == "surveySpecific"
        sort_based_on_survey_specific_info(sort_order)
      elsif sort_param =~ /answers/
        sort_based_on_survey_answer(sort_param, sort_order)
      elsif sort_param =~ /column/
        sort_based_on_profile_answer(sort_param, sort_order)
      end
    end

    def sort_based_on_profile_answer(sort_param, sort_order)
      question_id = sort_param.split("column").last.to_i
      profile_question = ProfileQuestion.find(question_id)
      users_scope = User.where(:id => @response_by_user_hash.keys)
      user_ids = User.sorted_by_answer(users_scope, profile_question, sort_order).collect(&:id)
      get_response_ids_for_users(user_ids)
    end

    def sort_based_on_survey_answer(sort_param, sort_order)
      question_id = sort_param.split("answers").last.to_i
      ordered_answered_response_ids = SurveyAnswer.get_es_survey_answers({filter: {survey_id: @survey.id, response_id: @responses_hash.keys, common_question_id: question_id, is_draft: false}, sort: [{answer_text_sortable: sort_order}], source_columns: ["response_id"]}).collect(&:response_id).uniq
      unanswered_response_ids = @responses_hash.keys - ordered_answered_response_ids
      if sort_order == "asc"
        return unanswered_response_ids + ordered_answered_response_ids
      else
        return ordered_answered_response_ids + unanswered_response_ids
      end
    end

    def sort_based_on_survey_specific_info(sort_order)
      if @survey.engagement_survey?
        return sort_based_on_mentoring_connection_name(sort_order)
      else
        return sort_based_on_meeting_topic_name(sort_order)
      end
    end

    def sort_based_on_user_roles(sort_order)
      if @survey.engagement_survey?
        SurveyAnswer.get_es_survey_answers({ filter: { survey_id: @survey.id, response_id: @responses_hash.keys, is_draft: false }, sort: [{ connection_membership_role_name_string: sort_order }], source_columns: ["response_id"]}).collect(&:response_id).uniq
      else
        sort_based_on_user_details("role_name_string", sort_order)
      end
    end

    def sort_based_on_mentoring_connection_name(sort_order)
      @survey.survey_answers.where(:response_id => @responses_hash.keys).select(:response_id).joins(:group).order("groups.name #{sort_order}").collect(&:response_id).uniq
    end

    def sort_based_on_meeting_topic_name(sort_order)
      @survey.survey_answers.where(:response_id => @responses_hash.keys).select(:response_id).joins(member_meeting: :meeting).order("meetings.topic #{sort_order}").collect(&:response_id).uniq
    end

    def sort_based_on_survey_response_date(sort_order)
      SurveyAnswer.where(:survey_id => @survey.id, :response_id => @responses_hash.keys).group(:response_id).order("last_answered_at #{sort_order}").pluck(:response_id)
    end

    def sort_based_on_user_details(field, sort_order)
      user_ids = User.get_filtered_users("", with: { program_id: @survey.program_id, id: @response_by_user_hash.keys }, sort_field: field, sort_order: sort_order, per_page: ES_MAX_PER_PAGE, page: 1, source_columns: [:id])
      get_response_ids_for_users(user_ids)
    end

    def get_response_ids_for_users(user_ids)
      response_ids = []
      user_ids.each do |user_id|
        response_ids += @response_by_user_hash[user_id].map{|user_response| user_response.response_id}.uniq
      end
      response_ids
    end
  end

  class FilterResponses

    def initialize(survey, options)
      @survey = survey
      @options = options
      @response_ids = @survey.survey_answers.pluck("DISTINCT response_id")
    end

    def apply_filters
      filter_params = SurveyResponsesDataService::FilterResponses.dynamic_filter_params(@options)

      return @response_ids, [], 0 unless filter_params.present?

      with_options = {:survey_id => @survey.id, :is_draft => false}
      response_ids = @response_ids

      apply_date_filter!(filter_params[:date], with_options) if filter_params[:date].present?
      apply_survey_specific_filter!(filter_params[:survey_specific], with_options) if filter_params[:survey_specific].present?
      user_ids = get_users_from_user_based_filters(filter_params)

      response_ids = SurveyQuestionFilterService.new(@survey, filter_params[:survey_question_fields], @response_ids).filtered_response_ids if filter_params[:survey_question_fields].present?
      if filter_params[:user_roles].present?
        response_ids = apply_engagement_role_filters(filter_params, response_ids)
        response_ids = apply_meeting_role_filters(filter_params, response_ids)
      end

      with_options.merge!({:user_id => user_ids})

      if valid_filtering_with_options?(with_options)
        with_options.merge!(response_id: response_ids)
        response_ids = SurveyAnswer.get_es_survey_answers(filter: with_options, source_columns: ["response_id"]).collect(&:response_id).uniq
        return response_ids, user_ids, get_applied_filters_count(filter_params)
      else
        return [], user_ids, get_applied_filters_count(filter_params)
      end
    end

    def valid_filtering_with_options?(with_options)
      with_options[:user_id].size > 0 && (!with_options.has_key?(:group_id) || with_options[:group_id].size > 0) && (!with_options.has_key?(:member_meeting_id) || with_options[:member_meeting_id].size > 0)
    end

    def apply_survey_specific_filter!(filter_name, with_options)
      if @survey.engagement_survey?
        es_options = {search_conditions: {fields: ["name"], search_text: filter_name.strip}, must_filters: {program_id: @survey.program_id}, per_page: ES_MAX_PER_PAGE }
        group_ids = Group.get_filtered_group_ids(es_options)
        with_options.merge!({:group_id => group_ids})
      elsif @survey.meeting_feedback_survey?
        meeting_ids = Meeting.get_meeting_ids_by_topic(filter_name.strip, {program_id: @survey.program_id})
        member_meeting_ids = MemberMeeting.where(meeting_id: meeting_ids).pluck(:id)
        with_options.merge!({:member_meeting_id => member_meeting_ids})
      end
    end

    def apply_date_filter!(filter, with_options)
      return if filter.include?("null") || filter.include?("")
      es_date_range_format = ElasticsearchConstants::DATE_RANGE_FORMATS::DATE_WITH_TIME_AND_ZONE
      start_time = filter[0].to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH[es_date_range_format])
      end_time = filter[1].to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH[es_date_range_format])
      with_options.merge!({:last_answered_at => start_time..end_time})
      with_options.merge!({:es_range_formats => {:last_answered_at => es_date_range_format}})
    end

    def apply_sender_name_filter!(filter_name)
      User.get_filtered_users("", with: {"name_only.keyword" => filter_name.downcase, program_id: @survey.program_id}, per_page: ES_MAX_PER_PAGE, page: 1, source_columns: [:id])
    end

    def self.dynamic_filter_params(options)
      if options[:filter].present? && options[:filter] != "null"
        filter_values = options[:filter][:filters].values.delete_if{|filter| filter["filters"].present?}
        filter_values += options[:filter][:filters].values.map{|filter| filter["filters"].try(:values)}.flatten.compact

        name = filter_values.select{|v| v["field"] == "name"}
        date = filter_values.select{|v| v["field"] == "date"}
        survey_specific = filter_values.select{|v| v["field"] == "surveySpecific"}
        survey_question_fields = filter_values.select{|v| v["field"] =~ /answers/}
        profile_fields = filter_values.select{|v| v["field"] =~ /column/}
        roles = filter_values.select{|v| v["field"] =~ /roles/}
      end
      filter_params = Hash.new
      filter_params[:name] = name.first["value"] if name.present?
      filter_params[:survey_specific] = survey_specific.first["value"] if survey_specific.present?
      filter_params[:date] = [date.first["value"], date.last["value"]] if date.present?
      filter_params[:survey_question_fields] = survey_question_fields if survey_question_fields.present?
      filter_params[:profile_field_filters] = profile_fields if profile_fields.present?
      filter_params[:user_roles] = roles.first["value"] if roles.present?
      return filter_params
    end

    def get_users_from_user_based_filters(filter_params)
      # For filtering by user name
      user_ids = filter_params[:name].present? ? apply_sender_name_filter!(filter_params[:name]) : @survey.program.users.pluck(:id)
      # For filtering by user profile
      user_ids = UserAndMemberFilterService.apply_profile_filtering(user_ids, filter_params[:profile_field_filters], {:is_program_view => true, :program_id => @survey.program_id, :for_survey_response_filter => true}) if filter_params[:profile_field_filters].present?
      # For filterig by user roles
      user_ids = apply_role_filters(user_ids, SurveyResponsesDataService::FilterResponses.get_roles_from_filters(filter_params)) if filter_params[:user_roles].present?
      return user_ids
    end

    def apply_role_filters(user_ids, role_filter)
      return user_ids unless @survey.program_survey?
      program = @survey.program
      roles = role_filter & program.roles.pluck(:name)
      program.users.where(id: user_ids).for_role(roles).pluck(:id)
    end

    def apply_engagement_role_filters(filter_params, response_ids)
      return response_ids unless @survey.engagement_survey?
      role_ids = @survey.program.roles.for_mentoring.where(name: SurveyResponsesDataService::FilterResponses.get_roles_from_filters(filter_params)).pluck(:id)
      response_ids & @survey.survey_answers.joins("INNER JOIN connection_memberships 
                                                  ON (common_answers.group_id = connection_memberships.group_id AND 
                                                      common_answers.user_id = connection_memberships.user_id)").where(
                                                  "connection_memberships.role_id IN (?)", role_ids).pluck(:response_id).uniq
    end

    def apply_meeting_role_filters(filter_params, response_ids)
      return response_ids unless @survey.meeting_feedback_survey?
      roles = @survey.program.roles.pluck(:name) & SurveyResponsesDataService::FilterResponses.get_roles_from_filters(filter_params)
      case roles
      when [RoleConstants::MENTOR_NAME]
        response_ids & @survey.survey_answers.joins(:member_meeting).joins("INNER JOIN meetings ON (meetings.id = member_meetings.meeting_id)").where(
                                                            "meetings.owner_id != member_meetings.member_id").pluck(:response_id).uniq
      when [RoleConstants::STUDENT_NAME]
        response_ids & @survey.survey_answers.joins(:member_meeting).joins("INNER JOIN meetings ON (meetings.id = member_meetings.meeting_id)").where(
                                                            "meetings.owner_id = member_meetings.member_id").pluck(:response_id).uniq
      else
        return response_ids
      end
    end

    def self.get_roles_from_filters(filter_params)
      filter_params[:user_roles].gsub(/\s/,'').split(",")
    end

    def get_applied_filters_count(filter_params)
      count = 0
      count += 1 if filter_params[:user_roles].present?
      count += 1 if filter_params[:survey_question_fields].present?
      count += 1 if filter_params[:profile_field_filters].present?
      return count
    end
  end
end