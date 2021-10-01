module PopulatorManagerIntegrationTestUtils
  TEST_SPEC_FILE = Rails.root + 'test/populator_fixtures/files/perf_populator_spec_config.yml'
  TEST_IGNORE_LIST = ["organization", "organization_common", "large_organization_common", "group_mentoring_common", "member", "role", "role_question", "user", "pending_user"]
  INDIVIDUAL_LIST = ["subscription", "admin_message", "topic", "user_state_change", "post", "group_meeting", "admin_message_auto_email", "profile_answer", "mentor_offer", "scrap", "connection_answer", "mentoring_model_task", "mentor_request", "survey_question", "post", "private_note", "project_request", "three_sixty_survey_question", "three_sixty_survey_answer", "three_sixty_survey_assessee_question_info", "three_sixty_survey_assessee_competency_info", "group_mentoring_mentor_intensive", "group_mentoring_equal_mentor_mentee", "group_mentoring_mentee_intensive", "group", "mentor_role", "mentee_role", "employee_role", "mentoring_model_task_comment", "qa_question", "user_campaign_admin_message", "user_campaign_message_analytics", "user_campaign_message_job", "inbox_message", "user", "article", "mentor_recommendation"]
  EXCLUDED_FOR_PORTAL = ["mentoring_slot", "group_state_change", "connection_membership_state_change", "confidentiality_audit_log", "spot_meeting", "mentoring_model_facilitation_template", "mentoring_model_milestone_template", "mentoring_model_task_template", "mentoring_model_goal_template", "mentor_recommendation", "recommendation_preference"]

  def compare_counts_individual(node, parent, parent_key, child_model, percent_array, count_array, parent_model_type, options)
    options[:parent_scope_column] ||= "id"
    parent_models = parent.camelize.constantize.where(options[:parent_scope_column].to_s => parent_model_type.id)
    options[:additional_selects].each do |select_query|
      parent_models.select!(&select_query.to_sym)
    end
    parent_model_count = parent_models.count
    parent_model_ids = parent_models.collect(&:id)
    parent_counts_ary = get_parents_count(parent_model_count, percent_array)
    child_parent_count = build_array(parent_counts_ary, count_array)
    org = options[:organization]
    options[:parent_model_ids] = parent_model_ids
    program = parent_model_type
    ratio_from_db = 0
    options.merge!(percent_array: percent_array, count_array: count_array)
    valid_node = validate_individual_node(node, child_parent_count, org, program, options)
    if valid_node
      populator_puts "."
      options[:pass_list].push node
    else
      populator_puts "F"
      options[:fail_list].push child_model
      options[:mismatch_hash][child_model] = [parent, child_parent_count, ratio_from_db]
    end
  end

  def populator_puts(*args)
    print(*args)
  end

  def build_array(percent_array, count_array)
    combined_array = []
    count_array.each_with_index{|element, index| combined_array << [count_array[index], percent_array[index]] if percent_array[index] != 0 && count_array[index]!=0}
    combined_array 
  end

  def get_parents_count(total_count, percent_ary)
    PopulatorTask.get_parents_count_ary(total_count, percent_ary)
  end

  def validate_individual_node_for_program(node, child_parent_count, org, program, options={})
    valid_node = nil
    case node
      when "article"
        parent_model_count = org.members.active.count
        ratio_from_db = program.articles.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])  
      when "admin_message"
        parent_model_count =  program.users.active.count - program.admin_users.count 
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])  
        ratio_from_db = program.admin_messages.where(:campaign_message_id => nil, :program_id => program.id, :auto_email => false).count
      when "mentor_offer"
        ratio_from_db = program.mentor_offers.count
      when "mentor_request"
        parent_model_count = program.users.active.includes([:roles]).select{|user| user.is_student?}.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.mentor_requests.count
      when "private_note"
        ratio_from_db = program.connection_memberships.collect(&:private_notes).flatten.count
      when "admin_message_auto_email"
        ratio_from_db = program.admin_messages.where(:campaign_message_id => nil, :program_id => program.id, :auto_email => true).count
      when "connection_answer"
        group_ids = program.groups.pluck(:id)
        valid_node = true if program.connection_questions.count.zero? 
        ratio_from_db = Connection::Answer.where(:group_id => group_ids).count
      when "survey_question"
        survey_ids = program.surveys.where(type: Survey::Type.admin_createable).pluck(:id)
        parent_model_count = survey_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = SurveyQuestion.where(:survey_id => survey_ids).count
      when "three_sixty_survey_question"
        return true if program.three_sixty_surveys.count.zero?
        parent_model_count = program.three_sixty_surveys.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = ThreeSixty::SurveyQuestion.where(:three_sixty_survey_id => program.three_sixty_surveys).count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "spot_meeting"
        parent_model_count = program.users.active.select{|user| user.is_mentor? && !user.member.will_set_availability_slots?}.count
        parent_counts_array = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.meetings.where(:group_id => nil).count
        child_parent_count = build_array(parent_counts_ary, count_array)
        valid_node = true if parent_model_count.zero?
        valid_node = (parent_model_count > 0 && child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i <= ratio_from_db) || (parent_model_count.zero?) ? true : false
      when "group_meeting"
        parent_model_count = program.groups.active.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.meetings.where("group_id is not null").count
      when "email_event_log"
        parent_model_count = program.admin_messages.where("campaign_message_id is not null").count
        admin_message_ids = program.admin_messages.where("campaign_message_id is not null").collect(&:id)
        parent_count = get_parents_count(parent_model_count, percent_array)
        ratio_from_db = CampaignManagement::EmailEventLog.where(:message_id => admin_message_ids).count
        child_parent_count = build_array(parent_count, count_array)
      when "mentoring_slot"
        parent_model_count = program.users.active.select{|user| user.is_mentor? && user.member.will_set_availability_slots?}.count
        parent_counts_ary = percent_array.map{|x| (x * parent_model_count * 0.01).round}
        update_parent_count(parent_counts_ary, parent_model_count)
        ratio_from_db = program.mentoring_slots.count
        child_parent_count = build_array(parent_count, count_array)
      when "mentee_role"
        parent_model_count = program.users.active.includes([:roles]).reject{|user| user.is_admin_only?}.size
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.users.select{|u| u.is_student?}.count
      when "mentor_role"
        parent_model_count = program.users.active.includes([:roles]).reject{|user| user.is_admin_only?}.size
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.users.select{|u| u.is_mentor?}.count
      when "employee_role"
        valid_node = program.users.select {|u| u.is_employee?}.count == 0
      when "profile_answer"
        percent_count = options[:percent_array].first.is_a?(Array) ? options[:percent_array].first[0] : options[:percent_array].first
        return program.roles.non_administrative.all? do |role|
          users = role.users
          users.select{|user| user.profile_answers.count > 0}.count == (users.count * percent_count * 0.01).round
        end
      when "user_campaign_admin_message"
        parent_model_count = program.user_campaigns.collect(&:campaign_messages).flatten.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.admin_messages.where("campaign_message_id is not null").count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "qa_question"
        parent_model_count = program.users.active.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.qa_questions.count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "topic"
        ratio_from_db = program.topics.count
      when "post"
        parent_model_count = program.topics.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.posts.count
        valid_node = (child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i <= ratio_from_db) ? true: false
      when "subscription"
        user_ids = []
        program.roles.non_administrative.each do |role|
          user_ids += role.users.active.pluck(:id)
        end
        parent_model_count = user_ids.size
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db =  Subscription.where(:user_id => user_ids).count
      when "group"
        user_ids = program.users.active.pluck(:id)       
        parent_model_count = user_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.groups.count
      when "scrap"
        parent_model_count = program.groups.where(status: ScrapPopulator::ALLOWED_GROUP_STATE).count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.scraps.count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "user_campaign_message_job"
        cm_ids = program.user_campaigns.collect(&:campaign_message_ids)
        parent_model_count = cm_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = CampaignManagement::UserCampaignMessageJob.where(:campaign_message_id => cm_ids.reject(&:blank?)).count
      when "user_campaign_message_analytics"
        cm_ids = program.user_campaigns.collect(&:campaign_message_ids)
        parent_model_count = cm_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => cm_ids.reject(&:blank?)).count
      when "mentoring_model_task"
        group = program.groups.active.last
        valid_node = group.nil? ? true : (group.mentoring_model.mentoring_model_task_templates.count <= group.mentoring_model_tasks.count ? true : false)
      when "mentoring_model_task_comment"
        parent_model_count = program.mentoring_model_tasks.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.mentoring_model_tasks.collect(&:comments).flatten.count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "three_sixty_survey_assessee"
        ratio_from_db = program.three_sixty_survey_assessees.count
      when "three_sixty_survey_reviewer"
        ratio_from_db = program.three_sixty_surveys.collect(&:reviewers).flatten.count
      when "three_sixty_survey_answer"
        return true if program.three_sixty_surveys.count.zero?
        parent_model_count = program.three_sixty_surveys.first.reviewers.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.three_sixty_surveys.first.answers.count
      when "three_sixty_survey_assessee_question_info"
        return true if program.three_sixty_surveys.count.zero?
        ratio_from_db = program.three_sixty_survey_assessees.collect(&:survey_assessee_question_infos).flatten.count
        valid_node = child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i <= ratio_from_db ? true : false
      when "three_sixty_survey_assessee_competency_info"
        return true if program.three_sixty_surveys.count.zero?
        ratio_from_db = program.three_sixty_survey_assessees.collect(&:survey_assessee_competency_infos).flatten.count
        valid_node = child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i <= ratio_from_db ? true : false
      when "project_request"
        parent_model_count = program.users.select{|user| user.is_student?}.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.project_requests.count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        valid_node = true unless program.project_based?
      when "role_question"
        ratio_from_db = program.role_questions.count
        roles_count = program.roles.non_administrative.count
        count_array = [roles_count]
        child_parent_count = build_array(parent_count, count_array)
      when "group_mentoring_mentor_intensive"
        mentor_intensive_group_count = program.groups.select{|group| (group.mentor_memberships.count == options[:nodes]["group_mentoring_mentor_intensive"]["mentor"]) && (group.student_memberships.count == options[:nodes]["group_mentoring_mentor_intensive"]["mentee"])}.count
        valid_node = mentor_intensive_group_count == options[:nodes]["group_mentoring_mentor_intensive"]["count"].first
      when "group_mentoring_mentee_intensive"
        mentee_intensive_group_count = program.groups.select{|group| (group.mentor_memberships.count == options[:nodes]["group_mentoring_mentee_intensive"]["mentor"]) && (group.student_memberships.count == options[:nodes]["group_mentoring_mentee_intensive"]["mentee"])}.count 
        valid_node = mentee_intensive_group_count == options[:nodes]["group_mentoring_mentee_intensive"]["count"].first
      when "group_mentoring_equal_mentor_mentee"
        equal_mentor_mentee_group_count = program.groups.select{|group| (group.mentor_memberships.count == options[:nodes]["group_mentoring_equal_mentor_mentee"]["mentor"]) && (group.student_memberships.count == options[:nodes]["group_mentoring_equal_mentor_mentee"]["mentee"])}.count 
        valid_node = equal_mentor_mentee_group_count == options[:nodes]["group_mentoring_equal_mentor_mentee"]["count"].first
      when "user_state_change"
        user_ids = program.users.active.pluck(:id)
        parent_model_count = user_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = UserStateChange.where(:user_id => user_ids).count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        valid_node = child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i <= ratio_from_db ? true : false
      when "inbox_message"
        member_ids = org.members.active.pluck(:id)
        parent_model_count = member_ids.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = Message.where(:sender_id => member_ids).count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "user"
        parent_model_count = org.members.active.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.users.where(:member_id => member_ids, state: [User::Status::SUSPENDED, User::Status::ACTIVE]).count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      when "mentor_recommendation"
        parent_model_count = program.student_users.count
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        ratio_from_db = program.mentor_recommendations.count
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
      end
      valid_node ||= child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i == ratio_from_db ? true : false
  end

  def validate_individual_node_for_portal(node, child_parent_count, org, program, options={})
    valid_node = nil
    case node
      when "group", "mentoring_model_task", "group_mentoring_mentor_intensive", "group_mentoring_mentee_intensive", "group_mentoring_equal_mentor_mentee"
        return program.groups.count == 0
      when "mentor_offer"
        return program.mentor_offers.count == 0
      when "mentor_request"
        return program.mentor_requests.count == 0
      when "private_note"
        return program.connection_memberships.count == 0
      when "spot_meeting"
        return program.meetings.where(:group_id => nil).count == 0
      when "group_meeting"
        return program.meetings.where("group_id is not null").count == 0
      when "mentoring_slot"
        return program.mentoring_slots.count == 0
      when "mentor_role"
        return program.users.select {|u| u.is_mentor?}.count == 0
      when "mentee_role"
        return program.users.select {|u| u.is_student?}.count == 0
      when "employee_role"
        parent_model_count = program.users.active.includes([:roles]).reject{|user| user.is_admin_only?}.size
        parent_counts_ary = get_parents_count(parent_model_count, options[:percent_array])
        child_parent_count = build_array(parent_counts_ary, options[:count_array])
        ratio_from_db = program.users.select{|u| u.is_employee?}.count
      when "scrap"
        return program.scraps.count == 0
      when "project_request"
        return program.project_requests.count == 0
      else
        return validate_individual_node_for_program(node, child_parent_count, org, program, options)
      end
      valid_node ||= child_parent_count.map{|x| x.inject(:*)}.inject(:+).to_i == ratio_from_db ? true : false
  end

  def validate_individual_node(node, child_parent_count, org, program, options={})
    if program.is_a?(CareerDev::Portal)
      validate_individual_node_for_portal(node, child_parent_count, org, program, options)
    else
      validate_individual_node_for_program(node, child_parent_count, org, program, options)
    end
  end
end