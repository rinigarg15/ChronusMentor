require_relative './../../../demo/code/demo_helper'
require "populator"
require "faker"
RANDOM_WORDS = %w(this kind of probability histogram is called a Markov Chain after Andrei Markov the fellow who invented it It turns out that Markov Chains can actually be used for things other than generating random text They are used in image processing for feature recognition and can be used to analyze finite state machines for bottlenecks and critical paths the states which occur most often are where the bottlenecks are This was long before digital audio this was done with razor blades Today it's called sampling and the influence of these bands is felt in nearly all branches of modern pop music)
class PerformancePopulator < DataPopulator

  def generate(settings)
    self.class.benchmark_wrapper "Populator" do
      program_objects = create_program(settings[:name], settings[:subdomain].dup, settings[:program_options])
      organization = program_objects[1].reload
      DataPopulator.populate_default_contents(organization)
      program = program_objects[0].reload
      calendar_setting = program.calendar_setting
      calendar_setting.update_attributes!(allow_create_meeting_for_mentor: true)
      organization.assign_default_theme
      populate_sections(organization, settings[:sections])
      roles_array = program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
      additional_programs = populate_programs(organization, settings[:additional_programs])
      admin_objects = create_program_admin(program)
      assign_owner!([program] + additional_programs, admin_objects[:user])
      populate_forums(program, settings[:forums])
      profile_questions = populate_profile_questions(organization, settings[:additional_profile_questions])
      new_profile_questions = profile_questions[1]
      populate_role_questions(program, new_profile_questions, roles: roles_array)
      populate_bulk_mentors_and_mentees(organization, program, settings[:mentors], settings[:students], roles: roles_array)
      all_mentors = program.mentor_users.active
      all_students = program.student_users.active
      # The below method call, is to populate a few 100 users of different statuses.
      populate_tags(settings[:tags])
      populate_additional_users_in(organization, additional_programs, all_mentors, all_students, settings[:additional_users])
      populate_bulk_profile_answers(program, all_mentors, all_students)
      populate_bulk_membership_requests(organization, program, settings[:membership_requests], admin_objects[:user], roles: roles_array)
      populate_bulk_groups(program, all_mentors, all_students, admin_objects[:user], settings[:groups])
      populate_bulk_mentor_requests(program, all_mentors.dup, all_students.dup, settings[:mentor_requests], admin_user: admin_objects[:user])
      # Call this after all the groups are created through all means (mentor request acceptance etc.)
      populate_bulk_scraps(program)
      populate_bulk_qa(program, all_mentors, all_students, settings[:qas], settings[:qa_answers])
      populate_bulk_articles(program, organization, all_mentors, settings[:articles], settings[:article_comments])
      populate_bulk_forum_topics_posts(program, all_mentors, all_students, settings[:topics], settings[:posts], settings[:forum_subscriptions])
      populate_resources(organization, roles_array, settings[:resources])
      populate_program_invitations(program, admin_objects[:user], settings[:program_invitations], roles: roles_array)
      populate_surveys(program, settings[:surveys])
      populate_survey_answers(program, all_mentors, all_students, settings[:survey_answers])
      # Availability slots per mentor
      populate_availability_slots(program, all_mentors, all_students, settings[:availability_slots_per_mentor])
      populate_spot_meeting_requests(program, all_mentors, all_students, settings[:spot_meeting_requests])
      # Creates a admin messages for all the mentors and mentees
      populate_admin_messages(admin_objects[:member], program, all_mentors, all_students, settings[:admin_messages])
      populate_inbox_messages(organization, all_mentors, all_students, settings[:inbox_messages])
      populate_connection_questions(program, settings[:connection_questions])
      populate_connection_answers(program)
      populate_program_events(program, admin_objects[:user], settings[:program_events])
      populate_announcements(program, admin_objects[:user], settings[:announcements])
      populate_additional_roles(program, 100)
      populate_groups_with_mentoring_connections_v2(program, settings)
      program.create_default_group_closure_columns!
      assign_roles!(Array(admin_objects[:user]), RoleConstants::ADMIN_NAME, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], false)
      enable_features!(organization)
      update_counter_cache_columns_sql(
        qa_question: ["qa_questions", "qa_answers"],
        topic: ["topics", "posts"],
        user: ["users", "qa_answers"],
        profile_question: ["profile_questions", "profile_answers"],
        common_question: ["common_questions", "common_answers"],
        forum: ["forums", "topics"],
        location: ["locations", "profile_answers"]
      )
    end
  end

  def generate_pbe(perf_program, settings)
    self.class.benchmark_wrapper "Populator" do
      organization = perf_program.organization
      program = populate_programs(organization, 1, settings[:program_options].merge(name: settings[:name])).first
      roles_array = program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
      admin_member = perf_program.owner.member
      admin_user = admin_member.user_in_program(program)
      admin_objects = {user: admin_user, member: admin_member}

      populate_forums(program, settings[:forums])
      populate_role_questions(program, organization.profile_questions, roles: roles_array)

      all_mentors = perf_program.mentor_users.active
      all_students = perf_program.student_users.active
      populate_additional_users_in(organization, [program], all_mentors, all_students, settings[:additional_users])
      all_mentors = program.mentor_users.active
      all_students = program.student_users.active

      populate_bulk_profile_answers(program, all_mentors, all_students)
      populate_bulk_membership_requests(organization, program, settings[:membership_requests], admin_objects[:user], roles: roles_array)
      populate_bulk_groups(program, all_mentors, all_students, admin_objects[:user], settings[:groups].merge(project_based: true))
      populate_project_requests(program, settings[:project_requests])
      populate_bulk_scraps(program)
      populate_bulk_qa(program, all_mentors, all_students, settings[:qas], settings[:qa_answers])
      populate_bulk_articles(program, organization, all_mentors, settings[:articles], settings[:article_comments])
      populate_bulk_forum_topics_posts(program, all_mentors, all_students, settings[:topics], settings[:posts], settings[:forum_subscriptions])
      populate_program_invitations(program, admin_objects[:user], settings[:program_invitations], roles: roles_array)
      populate_surveys(program, settings[:surveys])
      populate_survey_answers(program, all_mentors, all_students, settings[:survey_answers])

      # Creates a admin messages for all the mentors and mentees
      populate_admin_messages(admin_objects[:member], program, all_mentors, all_students, settings[:admin_messages])
      populate_connection_questions(program, settings[:connection_questions])
      populate_connection_answers(program)
      populate_program_events(program, admin_objects[:user], settings[:program_events])
      populate_announcements(program, admin_objects[:user], settings[:announcements])
      populate_additional_roles(program, 100)
      populate_groups_with_mentoring_connections_v2(program, settings)
      assign_roles!(Array(admin_objects[:user]), RoleConstants::ADMIN_NAME, [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], false)
      update_counter_cache_columns_sql(
        qa_question: ["qa_questions", "qa_answers"],
        topic: ["topics", "posts"],
        user: ["users", "qa_answers"],
        profile_question: ["profile_questions", "profile_answers"],
        common_question: ["common_questions", "common_answers"],
        forum: ["forums", "topics"],
        location: ["locations", "profile_answers"]
      )
    end
  end

  def reset_all_mentoring_model(mentoring_model)
    mentoring_model.mentoring_model_milestone_templates.destroy_all
    mentoring_model.mentoring_model_goal_templates.destroy_all
    mentoring_model.mentoring_model_milestone_templates.destroy_all
    mentoring_model.mentoring_model_facilitation_templates.destroy_all
    mentoring_model.object_role_permissions.destroy_all
  end

  def build_goal_templates(mentoring_model, goal_template_count, options = {})
    translation_locales = options.delete(:translation_locales) || []
    goal_template_count.times do
      title = Populator.words(5..8)
      description = Populator.sentences(2..3)
      goal_template_hash = {
        title: append_locale_to_string(title, I18n.default_locale),
        description: append_locale_to_string(description, I18n.default_locale)
      }
      goal_template = mentoring_model.mentoring_model_goal_templates.build(goal_template_hash)
      set_title_and_description_for_object_in_locale(goal_template, title, description, translation_locales)
    end
    mentoring_model.save!
    mentoring_model.mentoring_model_goal_templates.collect(&:id)
  end

  def build_milestone_templates(mentoring_model, milestone_template_count, options = {})
    translation_locales = options.delete(:translation_locales) || []

    milestone_template_count.times do
      title = Populator.words(5..8)
      description = Populator.sentences(2..3)
      milestone_template_hash = {
        title: append_locale_to_string(title, I18n.default_locale),
        description: append_locale_to_string(description, I18n.default_locale)
      }
      milestone_template = mentoring_model.mentoring_model_milestone_templates.build(milestone_template_hash)
      set_title_and_description_for_object_in_locale(milestone_template, title, description, translation_locales)
    end
    mentoring_model.save!
    mentoring_model.mentoring_model_milestone_templates.collect(&:id)
  end

  def build_facilitation_templates_model(program, mentoring_model, facilitation_template_count, options = {})
    translation_locales = options.delete(:translation_locales) || []
    milestone_template_ids = options[:milestone_template_ids] || [nil]
    role_names = program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).map(&:name)
    facilitation_template_count.times do
      subject = Populator.words(5..8)
      message = Populator.sentences(2..3)
      facilitation_template_hash = {
        subject: append_locale_to_string(subject, I18n.default_locale),
        message: append_locale_to_string(message, I18n.default_locale),
        send_on: (1..10).to_a.sample,
        milestone_template_id: milestone_template_ids.sample,
        mentoring_model_id: mentoring_model.id
      }
      fm = mentoring_model.mentoring_model_facilitation_templates.build(facilitation_template_hash)
      fm.role_names = [role_names.sample]
      translation_locales.each do |locale|
        Globalize.with_locale(locale) do
          fm.subject = append_locale_to_string(subject, locale)
          fm.message = append_locale_to_string(message, locale)
        end
      end
      fm.save!
    end
  end

  def build_task_templates_model(program, mentoring_model, task_template_count, options = {})
    translation_locales = options.delete(:translation_locales) || []
    goal_template_ids = options[:goal_template_ids] || [nil]
    milestone_template_ids = options[:milestone_template_ids] || [nil]
    role_ids = program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).pluck(:id)
    other_task_template_ids_hash = {}
    task_template_count.times do
      title = Populator.words(5..8)
      description = Populator.sentences(2..3)
      task_template_hash = {}
      task_template_hash = {
        title: append_locale_to_string(title, I18n.default_locale),
        description: append_locale_to_string(description, I18n.default_locale),
        required: [true, false].sample,
        goal_template_id: goal_template_ids.sample,
        milestone_template_id: milestone_template_ids.sample,
        role_id: role_ids.sample,
        duration: 0,
        action_item_type: 0
      }
      if task_template_hash[:required]
        task_template_hash.merge!({
          duration: (1..10).to_a.sample,
          action_item_type: (0..2).to_a.sample,
          associated_id: ([nil] + [other_task_template_ids_hash[task_template_hash[:milestone_template_id]]]).sample
        })
        task_template_hash.merge!({specific_date: rand(1.year.ago..Time.now).to_date}) if task_template_hash[:associated_id].nil?
      end
      #TODO-CR: Create engagement survey type tasks
      task_template = mentoring_model.mentoring_model_task_templates.new(task_template_hash)
      set_title_and_description_for_object_in_locale(task_template, title, description, translation_locales)
      task_template.save
      other_task_template_ids_hash[task_template_hash[:milestone_template_id]] = (other_task_template_ids_hash[task_template_hash[:milestone_template_id]] ? other_task_template_ids_hash[task_template_hash[:milestone_template_id]].append(task_template.id) : [task_template.id]) if task_template_hash[:required]
      # other_task_template_ids_hash[task_template_hash[:milestone_template_id]].pop unless task_template_hash[:required]
    end
    program.save!
  end

  def build_goal_and_task_templates_model(program, mentoring_model, goal_template_count, task_template_count, facilitation_template_count)
    goal_template_ids = build_goal_templates(mentoring_model, goal_template_count)
    build_facilitation_templates_model(program, mentoring_model, facilitation_template_count)
    build_task_templates_model(program, mentoring_model, task_template_count, {goal_template_ids: goal_template_ids})
  end

  def build_milestone_and_task_templates_model(program, mentoring_model, milestone_template_count, task_template_count, facilitation_template_count)
    milestone_template_ids = build_milestone_templates(mentoring_model, milestone_template_count)
    build_facilitation_templates_model(program, mentoring_model, facilitation_template_count, {milestone_template_ids: milestone_template_ids})
    build_task_templates_model(program, mentoring_model, task_template_count, {milestone_template_ids: milestone_template_ids})
  end

  def build_milestones_goal_and_task_templates_model(program, mentoring_model, milestone_template_count, goal_template_count, task_template_count, facilitation_template_count)
    goal_template_ids = build_goal_templates(mentoring_model, goal_template_count)
    milestone_template_ids = build_milestone_templates(mentoring_model, milestone_template_count)
    build_facilitation_templates_model(program, mentoring_model, facilitation_template_count, {milestone_template_ids: milestone_template_ids})
    build_task_templates_model(program, mentoring_model, task_template_count, {milestone_template_ids: milestone_template_ids, goal_template_ids: goal_template_ids})
  end

  def build_permissions_for_program(mentoring_model, admin_permissions, users_permissions)
    admin_role_id = mentoring_model.program.roles.with_name([RoleConstants::ADMIN_NAME])
    user_role_ids = mentoring_model.program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])

    ObjectPermission::MentoringModel::PERMISSIONS.each do |permission|
      mentoring_model.send("#{admin_permissions[permission].to_i == 1 ? 'allow' : 'deny'}_#{permission}!", admin_role_id)
      mentoring_model.send("#{users_permissions[permission].to_i == 1 ? 'allow' : 'deny'}_#{permission}!", user_role_ids)
    end
  end

  def build_reset_and_set_permissions_for_task_template_model(program, mentoring_model, task_template_count, facilitation_template_count)
    reset_all_mentoring_model(mentoring_model)
    admin_permissions = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users_permissions = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    build_permissions_for_program(mentoring_model, admin_permissions, users_permissions)
    build_facilitation_templates_model(program, mentoring_model, facilitation_template_count)
    build_task_templates_model(program, mentoring_model, task_template_count)
  end

  def build_groups_with_task_template_model(program, groups, group_start_count, group_end_count)
    DataPopulator.benchmark_wrapper("Only Task Population") do
      groups[group_start_count..group_end_count].each do |group|
        unless group.object_role_permissions.present?
          ActiveRecord::Base.transaction do
            Group::MentoringModelCloner.new(group, program, program.default_mentoring_model).copy_mentoring_model_objects
            DataPopulator.dot
          end
        end
      end
    end
  end

  def build_reset_and_set_permissions_for_goal_and_task_template_model(program, mentoring_model, goal_template_count, task_template_count, facilitation_template_count)
    reset_all_mentoring_model(mentoring_model)
    admin_permissions = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users_permissions = {"manage_mm_milestones"=>"0", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    build_permissions_for_program(mentoring_model, admin_permissions, users_permissions)
    build_goal_and_task_templates_model(program, mentoring_model, goal_template_count, task_template_count, facilitation_template_count)
  end

  def build_groups_with_goal_and_task_template_model(program, groups, group_start_count, group_end_count)
    DataPopulator.benchmark_wrapper("Tasks and Goals Population") do
      groups[group_start_count..group_end_count].each do |group|
        unless group.object_role_permissions.present?
          ActiveRecord::Base.transaction do
            Group::MentoringModelCloner.new(group, program, program.default_mentoring_model).copy_mentoring_model_objects
            DataPopulator.dot
          end
        end
      end
    end
  end

  def build_reset_and_set_permissions_for_milestone_and_task_template_model(program, mentoring_model, milestone_template_count, task_template_count, facilitation_template_count)
    reset_all_mentoring_model(mentoring_model)
    admin_permissions = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users_permissions = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"0", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    build_permissions_for_program(mentoring_model, admin_permissions, users_permissions)
    build_milestone_and_task_templates_model(program, mentoring_model, milestone_template_count, task_template_count, facilitation_template_count)
  end

  def build_groups_with_milestone_and_task_template_model(program, groups, group_start_count, group_end_count)
    DataPopulator.benchmark_wrapper("Tasks and Milestones Population") do
      groups[group_start_count..group_end_count].each do |group|
        unless group.object_role_permissions.present?
          ActiveRecord::Base.transaction do
            Group::MentoringModelCloner.new(group, program, program.default_mentoring_model).copy_mentoring_model_objects
            DataPopulator.dot
          end
        end
      end
    end
  end

  def build_reset_and_set_permissions_for_milestone_goal_and_task_template_model(program, mentoring_model, milestone_template_count, goal_template_count, task_template_count, facilitation_template_count)
    reset_all_mentoring_model(mentoring_model)
    admin_permissions = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    users_permissions = {"manage_mm_milestones"=>"1", "manage_mm_goals"=>"1", "manage_mm_tasks"=>"1", "manage_mm_messages"=>"1", "manage_mm_meetings"=>"0"}
    build_permissions_for_program(mentoring_model, admin_permissions, users_permissions)
    build_milestones_goal_and_task_templates_model(program, mentoring_model, milestone_template_count, goal_template_count, task_template_count, facilitation_template_count)
  end

  def build_groups_with_milestone_goal_and_task_template_model(program, groups, group_start_count, group_end_count)
    DataPopulator.benchmark_wrapper("Tasks, Goals and Milestones Population") do
      groups[group_start_count..group_end_count].each do |group|
        unless group.object_role_permissions.present?
          ActiveRecord::Base.transaction do
            Group::MentoringModelCloner.new(group, program, program.default_mentoring_model).copy_mentoring_model_objects
            DataPopulator.dot
          end
        end
      end
    end
  end

  def populate_groups_with_mentoring_connections_v2(program, settings)
    mentoring_model = program.default_mentoring_model
    start_index = 1
    group_interval = settings[:group_interval]
    group_progress_count = settings[:group_progress_count]
    task_template_count = settings[:task_template_count]
    goal_template_count = settings[:goal_template_count]
    milestone_template_count = settings[:milestone_template_count]
    facilitation_template_count = settings[:facilitation_template_count]
    groups = mentoring_model.groups.includes(:object_role_permissions).active

    build_reset_and_set_permissions_for_task_template_model(program, mentoring_model, task_template_count, facilitation_template_count)
    group_interval.times do |n|
      build_groups_with_task_template_model(program, groups, start_index+1, start_index + group_progress_count)
      start_index = start_index + group_progress_count
    end

    build_reset_and_set_permissions_for_goal_and_task_template_model(program, mentoring_model, goal_template_count, task_template_count, facilitation_template_count)
    group_interval.times do |n|
      build_groups_with_goal_and_task_template_model(program, groups, start_index+1, start_index+ group_progress_count)
      start_index = start_index + group_progress_count
    end

    build_reset_and_set_permissions_for_milestone_and_task_template_model(program, mentoring_model, milestone_template_count, task_template_count, facilitation_template_count)
    group_interval.times do |n|
      build_groups_with_milestone_and_task_template_model(program, groups, start_index+1, start_index+group_progress_count)
      start_index = start_index + group_progress_count
    end

    build_reset_and_set_permissions_for_milestone_goal_and_task_template_model(program, mentoring_model, milestone_template_count, goal_template_count, task_template_count, facilitation_template_count)
    group_interval.times do |n|
      build_groups_with_milestone_goal_and_task_template_model(program, groups, start_index+1, start_index+group_progress_count)
      start_index = start_index + group_progress_count
    end
  end

  def populate_tags(tags_count)
    self.class.benchmark_wrapper "Tags" do
      words = RANDOM_WORDS.uniq
      ActsAsTaggableOn::Tag.populate tags_count do |tag|
        tag.name = "#{words.sample}-#{self.class.random_string(8)}"
        self.class.dot
      end
    end
  end

  def populate_sections(organization, sections_count)
    self.class.benchmark_wrapper "Sections" do
      max_position = organization.sections.maximum(:position).to_i
      Section.populate sections_count do |section|
        section.program_id = organization.id
        section.title = Populator.words(3..6)
        section.description = Populator.sentences(2..5)
        section.position = (max_position += 1)
        section.default_field = false
        Section::Translation.populate 1 do |section_translation|
          section_translation.section_id = section.id
          section_translation.locale = "en"
          section_translation.title = section.title
          section_translation.description = section.description
        end
        self.class.dot
      end
    end
  end

  def populate_bulk_membership_requests(organization, program, membership_requests_count, admin_user, options = {})
    self.class.benchmark_wrapper "Membership Requests" do
      student_questions = program.membership_questions_for([RoleConstants::STUDENT_NAME])
      mentor_questions = program.membership_questions_for([RoleConstants::MENTOR_NAME])
      roles = options[:roles] || program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME])
      roles_hash = roles.group_by(&:name)
      mentor_role = roles_hash[RoleConstants::MENTOR_NAME][0]
      student_role = roles_hash[RoleConstants::STUDENT_NAME][0]
      flag = true
      count = 0
      MembershipRequest.populate membership_requests_count do |membership_request|
        membership_request.first_name = Faker::Name.first_name
        membership_request.last_name = Faker::Name.last_name
        membership_request.email = "membership_request_#{count}#{self.class.random_string}_#{Faker::Internet.email}"
        membership_request.program_id = program.id
        membership_request.status = [MembershipRequest::Status::UNREAD, MembershipRequest::Status::ACCEPTED, MembershipRequest::Status::ACCEPTED, MembershipRequest::Status::ACCEPTED, MembershipRequest::Status::REJECTED].sample
        profile_questions, role = (flag ? [mentor_questions, mentor_role] : [student_questions, student_role])
        membership_request.response_text = ((membership_request.status == MembershipRequest::Status::REJECTED) ? Populator.sentences(3..6) : nil)
        if membership_request.status != MembershipRequest::Status::UNREAD
          membership_request.accepted_as = role.name if membership_request.status == MembershipRequest::Status::ACCEPTED
          membership_request.admin_id = admin_user.id
        end
        membership_request.joined_directly = false
        temp_profile_questions = profile_questions.dup
        ProfileAnswer.populate profile_questions.size do |profile_answer|
          question = temp_profile_questions.shift
          profile_answer.profile_question_id = question.id
          profile_answer.ref_obj_id = membership_request.id
          profile_answer.ref_obj_type = MembershipRequest.to_s
          set_answer_text!(question, profile_answer)
        end
        RoleReference.populate 1 do |role_reference|
          role_reference.role_id = role.id
          role_reference.ref_obj_type = MembershipRequest.to_s
          role_reference.ref_obj_id = membership_request.id
        end
        if membership_request.status == MembershipRequest::Status::ACCEPTED
          populate_bulk_members(organization, program, role, 1, email: membership_request.email, first_name: membership_request.first_name, last_name: membership_request.last_name)
          membership_request.member_id = Member.last.id
        end
        flag = !flag
        count += 1
        self.class.dot
      end
    end
  end

  def populate_additional_users_in(organization, additional_programs, all_mentors, all_students, user_count, options = {})
    self.class.benchmark_wrapper "Additional Users in other programs" do
      member_ids = (all_mentors.collect(&:member_id) + all_students.collect(&:member_id)).shuffle
      additional_programs.each do |program|
        role_ids = program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME]).collect(&:id)
        User.populate user_count do |user|
          user.program_id = program.id
          user.member_id = member_ids.shift
          user.max_connections_limit = 5..10
          user.created_at = 10.days.ago...Time.now
          user.primary_home_tab = Program::RA_TABS::ALL_ACTIVITY
          user.state = options[:user_states] || User::Status::ACTIVE
          RoleReference.populate 1 do |role_reference|
            role_reference.role_id = role_ids
            role_reference.ref_obj_type = User.to_s
            role_reference.ref_obj_id = user.id
          end
        end
        self.class.dot
      end
    end
  end

  def populate_bulk_mentors_and_mentees(organization, program, mentor_count, mentee_count, options = {})
    roles = options[:roles] || program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    roles_hash = roles.group_by(&:name)

    self.class.benchmark_wrapper "Mentors" do
      populate_bulk_members(organization, program, roles_hash[RoleConstants::MENTOR_NAME][0], mentor_count, options)
    end

    self.class.benchmark_wrapper "Mentees" do
      populate_bulk_members(organization, program, roles_hash[RoleConstants::STUDENT_NAME][0], mentee_count, options)
    end
  end

  def populate_bulk_members(organization, program, role, object_count, options = {})
    count = Member.count
    t_and_c_date = 10.days.ago.to_date
    options.reverse_merge!(special_emails: true)
    subdomain = organization.subdomain
    all_tags_ids = ActsAsTaggableOn::Tag.pluck(:id)
    Member.populate object_count do |member|
      member.first_name = options[:last_name] || Faker::Name.first_name
      member.last_name = options[:first_name] || Faker::Name.last_name
      member.email = options[:email] || ((options[:special_emails] && count < 10) ? "#{subdomain}_#{role.name}#{count + 1}@chronus.com" : "member_#{count}_#{self.class.random_string}#{Faker::Internet.email}")
      member.organization_id = organization.id
      member.salt = 'da4b9237bacccdf19c0760cab7aec4a8359010b0'
      member.crypted_password = '688174433af60e1b89ecd9ed33022104bb6633e3'
      member.admin = false
      member.failed_login_attempts = false
      member.calendar_api_key = "#{role.name}#{count}#{self.class.random_string}"
      member.api_key = "#{role.name}#{count}#{self.class.random_string}api"
      member.terms_and_conditions_accepted = t_and_c_date
      member.state = options[:member_states] || [Member::Status::ACTIVE]*3 + [Member::Status::SUSPENDED, Member::Status::DORMANT]
      member.will_set_availability_slots = [true, true, true, false].sample
      member.password_updated_at = Time.now.utc
      member.availability_not_set_message = Populator.sentences(2..4) unless member.will_set_availability_slots
      if member.state != Member::Status::DORMANT
        User.populate 1 do |user|
          user.program_id = program.id
          user.member_id = member.id
          user.max_connections_limit = 70..80
          user.created_at = 10.days.ago...Time.now
          user.primary_home_tab = Program::RA_TABS::ALL_ACTIVITY
          user.state = ((member.state == Member::Status::SUSPENDED) ? User::Status::SUSPENDED : User::Status::ACTIVE)
          create_tags!(User, user, "tags", [*3..6].sample, all_tags_ids) if self.class.lucky?
          RoleReference.populate 1 do |role_reference|
            role_reference.role_id = role.id
            role_reference.ref_obj_type = User.to_s
            role_reference.ref_obj_id = user.id
          end
        end
      end
      count += 1
      self.class.dot
    end
  end

  def populate_bulk_profile_answers(program, all_mentors, all_students)
    self.class.benchmark_wrapper "Mentor Profile Answers" do
      mentor_members = all_mentors.collect(&:member_id)
      mentor_questions = program.profile_questions_for(RoleConstants::MENTOR_NAME).select { |q| q.non_default_type? && !q.file_type? }
      populate_bulk_answers(mentor_members, mentor_questions)
    end

    self.class.benchmark_wrapper "Mentee Profile Answers" do
      student_members = all_students.collect(&:member_id)
      student_questions = program.profile_questions_for(RoleConstants::STUDENT_NAME).select { |q| q.non_default_type? && !q.file_type? }
      populate_bulk_answers(student_members, student_questions)
    end
  end

  def populate_bulk_answers(member_ids, questions)
    members_size = member_ids.size
    members_array = member_ids.dup
    questions.each do |question|
      ProfileAnswer.populate members_size do |answer|
        member_id = members_array.shift
        answer.profile_question_id = question.id
        answer.ref_obj_id = member_id
        answer.ref_obj_type = Member.to_s
        set_answer_text!(question, answer)
      end
      members_array = member_ids.dup
      self.class.dot
    end
  end

  def populate_bulk_groups(program, all_mentors, all_students, admin_user, groups_count, options = {})
    self.class.benchmark_wrapper "Connections, Connection Memberships, Tasks, Milestones, Milestone Tasks, Meetings" do
      mentoring_template = program.mentoring_template
      milestones = mentoring_template.milestones.includes(:tasks)
      milestones_size = milestones.size
      student_count_range = [2, 3]
      group_iterator = 1
      current_time = Time.now
      temp_students = all_students.dup
      temp_mentors = all_mentors.dup
      additional_group_status = [Group::Status::CLOSED, Group::Status::INACTIVE, Group::Status::DRAFTED]
      additional_group_status += ([Group::Status::PENDING] * 3) if options[:project_based]
      Group.populate groups_count do |group|
        mentor = temp_mentors.shift
        if mentor.nil?
          temp_mentors = all_mentors.dup
          mentor = temp_mentors.shift
        end
        students = []
        if options[:from_external]
          students << all_students.shift
        else
          students_count = [student_count_range.sample, mentor.max_connections_limit].min
          temp_students = all_students.dup if students_count > temp_students.size
          students_count.times do
            students << temp_students.shift
          end
        end
        group.program_id = program.id
        group.created_at = rand(70).days.ago
        group.published_at = group.created_at
        group.name = "Mentoring Group - #{group_iterator}#{self.class.random_string}"
        group.mentoring_template_id = mentoring_template.id
        group.status = options[:from_external] ? Group::Status::ACTIVE : ([Group::Status::ACTIVE] * 6) + additional_group_status
        case group.status
        when Group::Status::DRAFTED
          group.creator_id = admin_user.id
        when Group::Status::CLOSED
          group.terminator_id = admin_user.id
          group.closed_at = current_time - 1.day
        end
        group_members = Array(mentor) + Array(students)
        group.created_at = current_time - [*1..100].sample.days
        temp_group_members = group_members.dup
        temp_group_members_size = temp_group_members.size
        group_user = temp_group_members.shift
        type = Connection::MentorMembership.to_s
        student_memberships = []
        mentor_memberships = []
        Connection::Membership.populate temp_group_members_size do |membership|
          membership.user_id = group_user.id
          membership.group_id = group.id
          membership.type = type
          membership.status = Connection::Membership::Status::ACTIVE
          membership.last_update_sent_time = group.created_at
          # for perf reasons, assigning the id itself and not gen rand
          membership.api_token = "#{membership.id}#{self.class.random_string}"
          type == Connection::MentorMembership.to_s ? (mentor_memberships << membership.id) : (student_memberships << membership.id)
          type = Connection::MenteeMembership.to_s
          group_user = temp_group_members.shift
        end
        unless [Group::Status::DRAFTED, Group::Status::PENDING].include?(group.status)
          group.expiry_time = group.created_at + (program.mentoring_period / 1.day).days
          memberships = student_memberships + mentor_memberships
          create_meeting(program, group_members.dup, group.created_at, 2..3, group_id: group.id, recurrent: (1..5).to_a.sample > 4, group: group)
          create_private_note(memberships, 10..15)
          create_coaching_goals(group.id, 5..10)
        end
        group_iterator += 1
        self.class.dot
      end
    end
  end

  def create_coaching_goals(group_id, count)
    CoachingGoal.populate count do |coaching_goal|
      coaching_goal.title = Populator.words(5..8)
      coaching_goal.description = Populator.sentences(3..5)
      coaching_goal.group_id = group_id
      CoachingGoalActivity.populate 3..4 do |coaching_goal_activity|
        coaching_goal_activity.coaching_goal_id = coaching_goal.id
        coaching_goal_activity.progress_value = [*1..100].sample
        coaching_goal_activity.message = Populator.sentences(2..3)
      end
    end
  end

  def create_private_note(membership_ids, count)
    Connection::PrivateNote.populate count do |private_note|
      private_note.connection_membership_id = membership_ids
      private_note.text = Populator.sentences(4..6)
    end
  end

  def populate_bulk_mentor_requests(program, all_mentors, all_students, requests_size, options = {})
    self.class.benchmark_wrapper "Mentor Requests" do
      options.reverse_merge!(additional_requests: true)
      count = 0
      if options[:additional_requests]
        primary_mentors = all_mentors.first(10)
        primary_students = all_students.first(10)
        all_mentors -= primary_mentors
        all_students -= primary_students
        primary_requests_count = options[:primary_requests_count] || 50
        primary_mentors.each do |primary_mentor|
          populate_mentor_requests(program, Array(primary_mentor), all_students.dup, primary_requests_count, options.merge(mentor_first: true))
          count += 1
        end
        primary_students.each do |primary_student|
          populate_mentor_requests(program, all_mentors.dup, Array(primary_student), primary_requests_count, options.merge(student_first: true))
          count += 1
        end
      end
      populate_mentor_requests(program, all_mentors.dup, all_students.dup, requests_size - (count * primary_requests_count), options)
    end
  end

  def populate_bulk_qa(program, all_mentors, all_students, question_count, answers_count, options = {})
    self.class.benchmark_wrapper "Questions and Answers" do
      all_mentor_ids = all_mentors.collect(&:id)
      all_student_ids = all_students.collect(&:id)
      answers_count = answers_count.to_a
      QaQuestion.populate question_count do |question|
        question.program_id = program.id
        question.user_id = all_student_ids
        question.summary = Populator.words(4..8)
        question.description = Populator.sentences(4..8)
        question.qa_answers_count = answers_count.sample
        QaAnswer.populate question.qa_answers_count do |answer|
          answer.qa_question_id = question.id
          answer.user_id = all_mentor_ids
          answer.content = Populator.sentences(2..4)
          answer.score = 0
        end
        self.class.dot
      end
    end
  end

  def populate_bulk_articles(program, organization, all_mentors, articles_count, article_comments_count, options = {})
    self.class.benchmark_wrapper "Articles" do
      organization_id = organization.id
      all_mentors_member_ids = all_mentors.collect(&:member_id)
      all_mentors_ids = all_mentors.collect(&:id)
      time_bound1 = organization.created_at
      time_bound2 = time_bound1 + 10.days
      time_bound3 = time_bound2 + 5.days
      all_tag_ids = ActsAsTaggableOn::Tag.pluck(:id)
      Article.populate articles_count do |article|
        article.view_count = 20..100
        article.helpful_count = 20..100
        article.author_id = all_mentors_member_ids
        article.organization_id = organization_id
        article.created_at = time_bound1..time_bound2
        ArticleContent.populate 1 do |article_content|
          article_content.title = Populator.words(3..6)
          article_content.type = ArticleContent::Type.all - [ArticleContent::Type::UPLOAD_ARTICLE]
          set_article_content!(article_content)
          article_content.created_at = article.created_at
          article_content.status = Array([ArticleContent::Status::PUBLISHED]*3 + [ArticleContent::Status::DRAFT])
          article_content.published_at = (article_content.status == ArticleContent::Status::PUBLISHED) ? time_bound2..time_bound3 : nil
          article.article_content_id = article_content.id
          create_tags!(ArticleContent, article_content, "labels", [*5..8].sample, all_tag_ids)
          Article::Publication.populate 1 do |publication|
            publication.program_id = program.id
            publication.article_id = article.id
            Comment.populate article_comments_count do |comment|
              comment.article_publication_id = publication.id
              comment.user_id = all_mentors_ids
              comment.body = Populator.sentences(3..5)
            end
          end
        end
        self.class.dot
      end
    end
  end

  def populate_bulk_forum_topics_posts(program, all_mentors, all_students, topics_count, posts_count, subscriptions_count)
    self.class.benchmark_wrapper "Forum, Topics, Posts" do
      all_mentors_ids = all_mentors.collect(&:id)
      all_student_ids = all_students.collect(&:id)
      forums = program.forums
      forums.each do |forum|
        subscribable_user_ids = []
        user_ids = forum.available_for_student? ? all_student_ids.dup : all_mentors_ids.dup
        Topic.populate(topics_count, per_query: 5_000) do |topic|
          topic.forum_id = forum.id
          topic.user_id = user_ids
          topic.title = Populator.words(5..10)
          topic.hits = 10..30
          topic.sticky_position = 0
          Post.populate(posts_count, per_query: 5_000) do |post|
            post.user_id = user_ids
            post.topic_id = topic.id
            post.body = Populator.sentences(2..4)
          end
          Subscription.populate 1 do |subscription|
            subscription.ref_obj_id = topic.id
            subscription.ref_obj_type = Topic.to_s
            subscription.user_id = topic.user_id
          end
          subscribable_user_ids = user_ids - [topic.user_id]
        end
        Subscription.populate(subscriptions_count, per_query: 5_000) do |subscription|
          subscription.ref_obj_id = forum.id
          subscription.ref_obj_type = Forum.to_s
          subscription.user_id = subscribable_user_ids
        end
        self.class.dot
      end
    end
  end

  def update_counter_cache_columns_sql(association_hash)
    self.class.benchmark_wrapper "Updating counter cache for #{association_hash.keys.join(", ")}" do
      association_hash.each_pair do |foreign_key, assoc_array|
        counter_cache_column = "#{assoc_array[1]}_count"
        values_array = []
        parent_table = assoc_array[0]
        has_many_table = assoc_array[1]
        count_result = ActiveRecord::Base.connection.execute(
          "select #{parent_table}.id, count(#{has_many_table}.id) from #{has_many_table} LEFT OUTER JOIN #{parent_table} ON #{has_many_table}.#{foreign_key}_id=#{parent_table}.id GROUP BY #{parent_table}.id"
        )
        count_result.to_a.each do |count_array|
          parent_table_id = count_array[0]
          assoc_count = count_array[1]
          values_array << "(#{parent_table_id},#{assoc_count})"
        end
        sql_string = values_array.join(",")
        ActiveRecord::Base.connection.execute(
          <<-SQL
            INSERT INTO #{parent_table} (id,#{counter_cache_column}) VALUES #{sql_string} ON DUPLICATE KEY UPDATE #{counter_cache_column}=VALUES(#{counter_cache_column})
          SQL
        )
        self.class.dot
      end
    end
  end

  def populate_mentor_requests(program, all_mentors, all_students, requests_size, options = {})
    MentorRequest.populate requests_size do |mentor_request|
      mentor_request.program_id = program.id
      mentor_request.status = AbstractRequest::Status.all + [AbstractRequest::Status::NOT_ANSWERED]*2
      selected_mentor = all_mentors.send(options[:mentor_first] ? :first : :sample)
      selected_student = all_students.send(options[:student_first] ? :first : :sample)
      mentor_request.receiver_id = selected_mentor.id
      mentor_request.sender_id = selected_student.id
      mentor_request.response_text = (mentor_request.status == AbstractRequest::Status::REJECTED) ? Populator.sentences(2..5) : nil
      mentor_request.message = Populator.paragraphs(1..3)
      mentor_request.type = MentorRequest.to_s
      mentor_request.show_in_profile = true
      if mentor_request.status == AbstractRequest::Status::ACCEPTED
        populate_bulk_groups(program, [selected_mentor], [selected_student], options[:admin_user], 1, from_external: true)
        mentor_request.group_id = Group.last.id
      end
      self.class.dot
    end
  end

  def populate_bulk_scraps(program)
    self.class.benchmark_wrapper "Scraps, Scraps:Receivers" do
      group_batch_size = 1000
      avg_scraps_per_group = 30
      scrap_batch_size = 1000

      # First populate all scraps without any receiver
      Group.where(:program_id => program).where("groups.status NOT IN (#{Group::Status::DRAFTED}, #{Group::Status::PENDING})").includes(:members).find_in_batches(:batch_size => group_batch_size) do |groups|
        Scrap.populate groups.size*avg_scraps_per_group do |scrap|
          group = groups.sample
          membership_ids = group.members.collect(&:member_id)
          scrap.group_id = group.id
          scrap.program_id = group.program_id
          sender_user_id = membership_ids.sample
          scrap.sender_id = sender_user_id
          scrap.subject = Populator.words(8..12)
          scrap.content = Populator.paragraphs(1..3)
          scrap.type = Scrap.name
          scrap.auto_email = false
          scrap.root_id = scrap.id
        end
      end
      # Now create receivers for all the scraps just created
      receiver_status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
      Scrap.where(:program_id => program).includes(:group => :members).find_in_batches(:batch_size => scrap_batch_size) do |scraps_batch|
        scrap_recievers_count = 0
        scraps_array = scraps_batch.inject([]) do |sa,scrap|
          membership_ids = scrap.group.members.collect(&:member_id)
          sender_id = scrap.sender_id
          receiver_ids = membership_ids - [sender_id]
          scrap_recievers_count += receiver_ids.size
          sa.push({ scrap_id: scrap.id, receiver_ids: receiver_ids })
        end
        Scraps::Receiver.populate scrap_recievers_count do |scrap_receiver|
          receiver = (scraps_array.first[:receiver_ids].size == 1) ? scraps_array.shift : scraps_array.first
          scrap_receiver.member_id = receiver[:receiver_ids].shift
          scrap_receiver.message_id = receiver[:scrap_id]
          scrap_receiver.status = receiver_status.sample
          scrap_receiver.api_token = "scraps-api-token-#{rand(36**36).to_s(36)}"
          scrap_receiver.message_root_id = receiver[:scrap_id]
        end
      end
    end
  end

  def populate_resources(organization, resources_count)
    self.class.benchmark_wrapper "Resources" do
      programs = organization.programs.active.includes(:roles)
      program_role_hash = {}
      programs.each do |program|
        program_role_hash[program.id] = program.roles.select{|role| [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME].include?(role.name) }.collect(&:id)
      end
      program_ids = programs.collect(&:id)
      Resource.populate resources_count do |resource|
        resource.title = Populator.words(3..5)
        resource.program_id = organization.id
        resource.content = Populator.paragraphs(2..5)
        Resource::Translation.populate 1 do |resource_translation|
          resource_translation.locale = "en"
          resource_translation.title = resource.title
          resource_translation.content = resource.content
          resource_translation.resource_id = resource.id
        end
        sample_program_ids = program_ids.sample(5)
        ResourcePublication.populate 2..5 do |resource_publication|
          resource_publication.resource_id = resource.id
          resource_publication.program_id = sample_program_ids.shift
          temp_role_ids = program_role_hash[resource_publication.program_id]
          RoleResource.populate 1..2 do |role_resource|
            role_resource.role_id = temp_role_ids.shift
            role_resource.resource_publication_id = resource_publication.id
          end
        end
      end

      Resource.populate resources_count do |resource|
        program_id = organization.programs.active.collect(&:id).sample
        resource.title = Populator.words(3..5)
        resource.program_id = program_id
        resource.content = Populator.paragraphs(2..5)
        Resource::Translation.populate 1 do |resource_translation|
          resource_translation.locale = "en"
          resource_translation.title = resource.title
          resource_translation.content = resource.content
          resource_translation.resource_id = resource.id
        end
        ResourcePublication.populate 1 do |resource_publication|
          resource_publication.resource_id = resource.id
          resource_publication.program_id = program_id
          temp_role_ids = program_role_hash[program_id]
          RoleResource.populate 1..2 do |role_resource|
            role_resource.role_id = temp_role_ids.shift
            role_resource.resource_publication_id = resource_publication.id
          end
        end
      end
    end
  end

  def populate_program_invitations(program, admin_user, program_invitations_count, options = {})
    self.class.benchmark_wrapper "Program Invitations" do
      invitation_iterator = ProgramInvitation.count
      lower_bound = program.created_at
      upper_bound = Time.now + 100.days
      role_ids = (options[:roles] && options[:roles].collect(&:id)) || program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME]).collect(&:id)
      ProgramInvitation.populate program_invitations_count do |program_invitation|
        program_invitation.user_id = admin_user.id
        program_invitation.code = "invitation#{invitation_iterator}#{self.class.random_string}"
        program_invitation.sent_to = "invitation_#{invitation_iterator}_#{self.class.random_string}_#{Faker::Internet.email}"
        program_invitation.expires_on = lower_bound..upper_bound
        program_invitation.program_id = program.id
        program_invitation.use_count = 0
        program_invitation.message = Populator.paragraphs(2..4)
        program_invitation.sent_on = program_invitation.expires_on - 30.days
        create_role_reference(ProgramInvitation, program_invitation.id, role_ids, [1, 2].sample)
        invitation_iterator += 1
        self.class.dot
      end
    end
  end

  def populate_surveys(program, survey_count, options = {})
    self.class.benchmark_wrapper "Surveys" do
      roles = options[:roles] || program.roles.with_name([RoleConstants::MENTOR_NAME,RoleConstants::STUDENT_NAME])
      role_ids = roles.collect(&:id)
      program_id = program.id
      choice_based = [CommonQuestion::Type::MULTI_CHOICE , CommonQuestion::Type::SINGLE_CHOICE]
      other_question = CommonQuestion::Type.all - [CommonQuestion::Type::FILE] - choice_based
      # TODO :: Add total_responses to Surveys and update it after populating survey answers.
      Survey.populate survey_count do |survey|
        survey.program_id = program_id
        survey.name = Populator.words(4..8)
        Survey::Translation.populate 1 do |survey_translation|
          survey_translation.name = survey.name
          survey_translation.survey_id = survey.id
          survey_translation.locale = "en"
        end
        iterator = 0
        number_of_question = (15..25).to_a.sample
        number_of_choice_based = 0.8*number_of_question

        SurveyQuestion.populate number_of_question do |common_question|
          common_question.type = SurveyQuestion.to_s
          common_question.program_id = program_id
          common_question.question_text = Populator.words(5..8)
          common_question.question_type = number_of_choice_based > 0 ? choice_based.sample : other_question.sample
          common_question.survey_id = survey.id
          common_question.position = iterator += 1
          common_question.required = [false, false, true]
          common_question.allow_other_option = [false, false, true]
          common_question.help_text = Populator.words(3..5)
          common_question.question_info = common_question_choice_based?(common_question.question_type) ? self.class.generate_random_question_info(CommonQuestion::SEPERATOR) : nil
          SurveyQuestion::Translation.populate 1 do |survey_question_translation|
            survey_question_translation.question_text = common_question.question_text
            survey_question_translation.help_text = common_question.help_text
            survey_question_translation.locale = "en"
            survey_question_translation.common_question_id = common_question.id
          end
          number_of_choice_based -= 1
        end
        create_role_reference(Survey, survey.id, role_ids, roles.count)
        self.class.dot
      end
    end
  end

  def populate_engagement_surveys(program, survey_count, options = {})
    self.class.benchmark_wrapper "EngagementSurvey" do
      program_id = program.id
      choice_based = [CommonQuestion::Type::MULTI_CHOICE , CommonQuestion::Type::SINGLE_CHOICE]
      other_question = CommonQuestion::Type.all - [CommonQuestion::Type::FILE] - choice_based
      # TODO :: Add total_responses to Surveys and update it after populating survey answers.
      EngagementSurvey.populate survey_count do |survey|
        survey.program_id = program_id
        survey.name = Populator.words(4..8)
        survey.total_responses = 0
        EngagementSurvey::Translation.populate 1 do |survey_translation|
          survey_translation.name = survey.name
          survey_translation.survey_id = survey.id
          survey_translation.locale = "en"
        end
        iterator = 0
        number_of_question = (4..7).to_a.sample
        number_of_choice_based = 0.8*number_of_question

        SurveyQuestion.populate number_of_question do |common_question|
          common_question.type = SurveyQuestion.to_s
          common_question.program_id = program_id
          common_question.question_text = Populator.words(5..8)
          common_question.question_type = number_of_choice_based > 0 ? choice_based.sample : other_question.sample
          common_question.survey_id = survey.id
          common_question.position = iterator += 1
          common_question.required = [false, false, true]
          common_question.allow_other_option = [false, false, true]
          common_question.help_text = Populator.words(3..5)
          common_question.question_info = common_question_choice_based?(common_question.question_type) ? self.class.generate_random_question_info(CommonQuestion::SEPERATOR) : nil
          SurveyQuestion::Translation.populate 1 do |survey_question_translation|
            survey_question_translation.question_text = common_question.question_text
            survey_question_translation.help_text = common_question.help_text
            survey_question_translation.locale = "en"
            survey_question_translation.common_question_id = common_question.id
          end
          number_of_choice_based -= 1
        end
        self.class.dot
      end
    end
  end

  def populate_survey_answers(program, all_mentors, all_students, survey_answers_count)
    self.class.benchmark_wrapper "Survey Answers" do
      mentor_surveys = program.surveys.for_mentors.includes(:survey_questions)
      student_surveys = program.surveys.for_students.includes(:survey_questions)
      mentor_student_surveys = mentor_surveys & student_surveys
      mentor_surveys -= mentor_student_surveys
      student_surveys -= mentor_student_surveys

      mentor_ids = all_mentors.collect(&:id)
      student_ids = all_students.collect(&:id)

      create_survey_answers(mentor_surveys, mentor_ids, survey_answers_count)
      create_survey_answers(student_surveys, student_ids, survey_answers_count)
      create_survey_answers(mentor_student_surveys, (mentor_ids + student_ids), survey_answers_count)
    end
  end

  def populate_availability_slots(program, all_mentors, all_students, slots_per_mentor)
    self.class.benchmark_wrapper "Mentoring Slots" do
      all_mentor_users = []
      all_mentors.includes(:member).each do |mentor|
        if mentor.member.will_set_availability_slots?
          all_mentor_users << mentor
        end
      end
      lower_bound = Time.now.beginning_of_day + 8.hours + 10.days
      higher_bound = lower_bound + 100.days
      randomizer = [*1..5]
      temp_slots_per_mentor = 0
      mentor_user = nil
      repeat_options_count = (MentoringSlot::Repeats.all.size - 1)
      repeats_arr = MentoringSlot::Repeats.all + Array.new(repeat_options_count * 9 - 1, MentoringSlot::Repeats::NONE)
      MentoringSlot.populate(all_mentor_users.size * slots_per_mentor, per_query: 5_000) do |slot|
        if temp_slots_per_mentor.zero?
          mentor_user = all_mentor_users.shift
          temp_slots_per_mentor = slots_per_mentor
        end
        slot.member_id = mentor_user.member_id
        slot.start_time = lower_bound..higher_bound
        slot.end_time = slot.start_time + randomizer.sample.hours
        slot.location = Populator.words(5..7)
        slot.repeats = repeats_arr
        slot.repeats_by_month_date = slot.repeats == MentoringSlot::Repeats::MONTHLY
        slot.repeats_on_week = (slot.repeats == MentoringSlot::Repeats::WEEKLY ? slot.start_time.wday : nil)
        temp_slots_per_mentor -= 1
        self.class.dot
        if slot.repeats != MentoringSlot::Repeats::MONTHLY
          users = {
            student: all_students.sample,
            mentor: mentor_user
          }
          create_meeting(program, users, slot.start_time, 1, non_group_meeting: true)
        end
        self.class.dot
      end
    end
  end

  def create_recurring_meetings(populator_meeting, group)
    meeting = Meeting.new(populator_meeting.attributes)
    meeting_rule = case (1..11).to_a.sample
    when 1 .. 7
      meeting.schedule_rule = Meeting::Repeats::DAILY
    when 8 .. 9
      meeting.repeats_on_week = [(0..6).to_a.sample]
      meeting.schedule_rule = Meeting::Repeats::WEEKLY
    when 10 .. 11
      meeting.repeats_by_month_date = %w(true false).sample
      meeting.schedule_rule = Meeting::Repeats::MONTHLY
    end
    meeting.repeats_end_date = group.expiry_time
    meeting.repeat_every = case (1..6).to_a.sample
    when 1 .. 2 then 1
    when 3 .. 4 then 2
    when 5 .. 6 then (1..30).to_a.sample
    end

    meeting.recurrent = true
    meeting.update_schedule
    meeting.schedule
  end

  def create_meeting(program, users, meeting_start_time, meetings_count, options = {})
    options.reverse_merge!(calendar_time_available: true, non_group_meeting: false)
    meeting_offset = program.calendar_setting.slot_time_in_minutes.minutes
    meeting_request = nil
    Meeting.populate meetings_count do |meeting|
      meeting.group_id = options[:group_id]
      meeting.topic = Populator.words(4..8)
      meeting.description = Populator.sentences(2..3)
      tentative_start_time = meeting_start_time + 10.days
      meeting.start_time = options[:start_time] || (tentative_start_time..(tentative_start_time + 30.days))
      meeting.end_time = meeting.start_time + meeting_offset
      meeting.location = Populator.words(5..7)
      meeting.owner_id = options[:non_group_meeting] ? users[:student].member_id : users.collect(&:member_id)
      meeting.active = true
      meeting.calendar_time_available = options[:calendar_time_available]
      meeting.program_id = program.id
      if options[:non_group_meeting]
        MeetingRequest.populate 1 do |meeting_request|
          meeting_request.program_id = program.id
          meeting_request.status = AbstractRequest::Status.all + [AbstractRequest::Status::NOT_ANSWERED]*2
          meeting_request.sender_id = users[:student].id
          meeting_request.receiver_id = users[:mentor].id
          meeting_request.show_in_profile = false
          meeting_request.type = MeetingRequest.to_s
          meeting.meeting_request_id = meeting_request.id
        end
      elsif options[:recurrent] && options[:group].expiry_time > meeting.start_time
        meeting.schedule = create_recurring_meetings(meeting, options[:group])
        meeting.recurrent = true
      end
      temp_users = options[:non_group_meeting] ? users.values : users
      temp_member_ids = temp_users.collect(&:member_id)
      MemberMeeting.populate temp_users.size do |member_meeting|
        member_id = temp_member_ids.shift
        member_meeting.member_id = member_id
        member_meeting.meeting_id = meeting.id
        member_meeting.attending = get_member_meeting_status(member_id, meeting, meeting_request)
        member_meeting.reminder_time = meeting.start_time - MemberMeeting::DEFAULT_MEETING_REMINDER_TIME
        member_meeting.reminder_sent = false
        member_meeting.feedback_request_sent = false
        if self.class.lucky?
          member_meeting.feedback_request_sent = true
        end
      end
      self.class.dot
    end
  end

  def populate_spot_meeting_requests(program, all_mentors, all_students, meeting_request_count)
    self.class.benchmark_wrapper "Meeting Requests" do
      eligible_mentors = []
      all_mentors.includes(:member).each do |mentor|
        unless mentor.member.will_set_availability_slots?
          eligible_mentors << mentor
        end
      end
      randomizer = [*1..5]
      meeting_request_count.times do |iterator|
        current_time = Time.now.beginning_of_day + iterator.day
        users = {
          student: all_students.sample,
          mentor: eligible_mentors.sample
        }
        create_meeting(program, users, current_time + randomizer.sample.hours, 1, non_group_meeting: true, calendar_time_available: false)
        self.class.dot
      end
    end
  end

  def populate_admin_messages(admin_member, program, all_mentors, all_students, admin_message_count)
    self.class.benchmark_wrapper "Admin Messages" do
      all_member_ids = all_mentors.collect(&:member_id) + all_students.collect(&:member_id)
      admin_member_id = admin_member.id
      # TODO :: Need to set root id
      AdminMessage.populate admin_message_count do |admin_message|
        admin_message.program_id = program.id
        admin_message.sender_id = admin_member_id
        admin_message.subject = Populator.words(8..12)
        admin_message.content = Populator.paragraphs(1..3)
        admin_message.type = AdminMessage.to_s
        admin_message.auto_email = false
        AdminMessages::Receiver.populate 1 do |admin_message_receiver|
          admin_message_receiver.member_id = all_member_ids.sample
          admin_message_receiver.message_id = admin_message.id
          admin_message_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
          admin_message_receiver.api_token = "adminmessage-api-token-#{self.class.random_string}_#{admin_message_receiver.member_id}"
        end
        self.class.dot
      end
    end
  end

  def populate_inbox_messages(organization, all_mentors, all_students, message_count)
    self.class.benchmark_wrapper "Inbox Messages" do
      mentor_members = all_mentors.collect(&:member_id)
      student_members = all_students.collect(&:member_id)
      all_member_ids = mentor_members + student_members
      iterator = 0
      # TODO :: Need to set root id
      Message.populate message_count do |message|
        message.program_id = organization.id
        message.sender_id = all_member_ids.sample
        message.subject = Populator.words(8..12)
        message.content = Populator.paragraphs(1..3)
        message.type = Message.to_s
        message.auto_email = false
        Messages::Receiver.populate 1 do |message_receiver|
          message_receiver.member_id = (all_member_ids - [message.sender_id]).sample
          message_receiver.message_id = message.id
          message_receiver.status = [AbstractMessageReceiver::Status::UNREAD, AbstractMessageReceiver::Status::READ]
          message_receiver.api_token = "message-api-token-#{iterator += 1}#{self.class.random_string}"
        end
        self.class.dot
      end
    end
  end

  def create_tags!(klass, object, context, tag_count, tag_ids)
    selected_tag_ids = tag_ids.sample(tag_count)
    ActsAsTaggableOn::Tagging.populate selected_tag_ids.count do |tagging|
      tagging.taggable_id = object.id
      tagging.taggable_type = klass.to_s
      tagging.context = context
      tagging.tag_id = selected_tag_ids.shift
    end
  end

  def create_location(answer)
    Location.populate 1 do |location|
      location.reliable = false
      location.full_address = answer.answer_text
      location.profile_answers_count = 1
      answer.location_id = location.id
    end
  end

  def popluate_engagement_survey_answers(tasks, response_id)
    self.class.benchmark_wrapper "Engagement Survey Answers" do
      type = SurveyAnswer.to_s
      last_survey_answer = SurveyAnswer.last.id
      create = [true, false]
      count = 1
      ActiveRecord::Base.transaction do
        tasks.each do |task|
          user_id = Connection::Membership.where(id: task.connection_membership_id).pluck(:user_id).first
          questions = CommonQuestion.where(:type => "SurveyQuestion").where(:survey_id => task.action_item_id).select([:id, :question_type, :question_info])
          questions.each do |ques|
            next unless create.sample
            survey_answer = SurveyAnswer.new()
            survey_answer.survey_id = task.action_item_id
            survey_answer.user_id = user_id
            survey_answer.common_question_id = ques.id
            survey_answer.response_id = response_id
            survey_answer.task_id = task.id
            set_common_answer_text!(ques, survey_answer)
            survey_answer.type = type
            survey_answer.save(:validate => false)
            puts count if (count%1000 == 0)
            count += 1
          end
          response_id += 1
        end
      end
      puts "NUmber of survey Answers populated = #{count}"
    end
  end

private

  def get_roles(roles)
    Array (([roles] * 3) + ([roles.first] * 2) + ([roles.last] * 2) << []).sample
  end

  def set_article_content!(article_content)
    article_type = article_content.type
    case article_type
    when ArticleContent::Type::TEXT
      article_content.body = Populator.sentences(3..6)
    when ArticleContent::Type::MEDIA
      article_content.body = Populator.sentences(3..6)
      article_content.embed_code = "https://www.youtube.com/watch?v=L9dC8BQnkw0"
    when ArticleContent::Type::LIST
      ArticleListItem.populate 5..10 do |article_list_item|
        article_list_item.type = [SiteListItem.to_s, BookListItem.to_s]
        article_list_item.content = ((article_list_item.type == BookListItem.to_s) ? "A Game of Thrones (A Song of Ice and Fire, Book 1)" : "http://www.railstips.org/")
        article_list_item.description = Populator.sentences(3..6)
        article_list_item.article_content_id = article_content.id
      end
    end
  end

  #TODO-CR: modify response_id
  def create_survey_answers(surveys, user_ids, survey_answer_count)
    randomizer = [*1..5]
    surveys.each do |survey|
      survey.survey_questions.where("question_type != #{CommonQuestion::Type::FILE}").each do |survey_question|
        temp_user_ids = user_ids.dup
        SurveyAnswer.populate(survey_answer_count, per_query: 25_000) do |survey_answer|
          survey_answer.user_id = temp_user_ids.shift
          survey_answer.common_question_id = survey_question.id
          survey_answer.last_answered_at = Time.now + randomizer.sample.days
          set_common_answer_text!(survey_question, survey_answer)
          survey_answer.type = SurveyAnswer.to_s
          self.class.dot
        end
      end
    end
  end

  def create_role_reference(klass, klass_id, role_ids, role_count = 1)
    raise "Role ids and role_count mismatch" if role_ids.size < role_count
    temp_role_ids = role_ids.dup
    RoleReference.populate role_count do |role_reference|
      role_reference.ref_obj_id = klass_id
      role_reference.ref_obj_type = klass.to_s
      role_reference.role_id = (role_count == 1 ? temp_role_ids.sample : temp_role_ids.shift)
    end
  end

  def get_member_meeting_status(member_id, meeting, meeting_request)
    is_owner = (meeting.owner_id == member_id)
    if meeting_request
      case meeting_request.status
      when AbstractRequest::Status::WITHDRAWN
        is_owner ? MemberMeeting::ATTENDING::NO : MemberMeeting::ATTENDING::NO_RESPONSE
      when AbstractRequest::Status::REJECTED
        is_owner ? MemberMeeting::ATTENDING::YES : MemberMeeting::ATTENDING::NO
      when AbstractRequest::Status::ACCEPTED
        MemberMeeting::ATTENDING::YES
      when AbstractRequest::Status::NOT_ANSWERED
        is_owner ? MemberMeeting::ATTENDING::YES : MemberMeeting::ATTENDING::NO_RESPONSE
      end
    elsif is_owner
      MemberMeeting::ATTENDING::YES
    else
      [MemberMeeting::ATTENDING::NO_RESPONSE]*3 + [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO]
    end
  end

  def set_answer_text!(profile_question, answer)
    question_type = profile_question.question_type
    case question_type
    when ProfileQuestion::Type::MULTI_CHOICE
      choices = self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [*3..7])
    when ProfileQuestion::Type::ORDERED_OPTIONS
      choices = self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [profile_question.options_count])
    when ProfileQuestion::Type::SINGLE_CHOICE
      choices = self.class.pick_random_answer(profile_question.default_question_choices.collect(&:text), [profile_question.options_count])
    when ProfileQuestion::Type::LOCATION
      set_location!(answer)
    when ProfileQuestion::Type::TEXT
      answer.answer_text = Populator.sentences(1..2)
    when ProfileQuestion::Type::STRING
      answer.answer_text = Populator.words(2)
    when ProfileQuestion::Type::MULTI_STRING
      answer.answer_text = Populator.words(1..4).split(" ").join(ProfileAnswer::MULTILINE_SEPERATOR)
    when ProfileQuestion::Type::MULTI_EDUCATION, ProfileQuestion::Type::EDUCATION
      edu_array = []
      Education.populate((question_type == ProfileQuestion::Type::EDUCATION) ? 1 : 2..4) do |edu|
        edu.school_name = Demo::Educations::Schools
        edu.degree = Demo::Educations::MentorDegrees
        edu.major = Demo::Educations::Majors
        edu.graduation_year = 1990..2009
        edu.profile_answer_id = answer.id
        edu_array << [edu.school_name, edu.degree, edu.major].join(ProfileAnswer::SEPERATOR)
      end
      answer.answer_text = edu_array.join(ProfileAnswer::MULTILINE_SEPERATOR)
    when ProfileQuestion::Type::MULTI_EXPERIENCE, ProfileQuestion::Type::EXPERIENCE
      exp_array = []
      Experience.populate((question_type == ProfileQuestion::Type::EXPERIENCE) ? 1 : 2..4) do |exp|
        exp.job_title = Demo::Workex::MentorJobTitles
        exp.start_year = 1990..2000
        exp.end_year = 2000..2009
        exp.start_month = 0..12
        exp.end_month = 0..12
        exp.company = Demo::Workex::Organizations
        exp.current_job = false
        exp.profile_answer_id = answer.id
        exp_array << [exp.job_title, exp.company].join(ProfileAnswer::SEPERATOR)
      end
      answer.answer_text = exp_array.join(ProfileAnswer::MULTILINE_SEPERATOR)
    end

    if choices.present?
      question_choices = profile_question.default_question_choices.index_by(&:text)
      position = 0
      answer.answer_text = choices.join(",")
      choices.each do |text|
        question_choice = question_choices[text]
        AnswerChoice.populate 1 do |answer_choice|
          answer_choice.ref_obj_id = answer.id
          answer_choice.question_choice_id = question_choice.id
          answer_choice.ref_obj_type = ProfileAnswer.name
          answer_choice.position = position
          position += 1 if question_type == ProfileQuestion::Type::ORDERED_OPTIONS
        end
      end
    end
  end

  def set_location!(answer)
    answer.answer_text = Populator.interpret_value(Demo::Locations::Addresses).values.join(", ")
    create_location(answer)
  end

  def set_title_and_description_for_object_in_locale(object, title, description, locales)
    locales.each do |locale|
      Globalize.with_locale(locale) do
        object.title = append_locale_to_string(title, locale)
        object.description = append_locale_to_string(description, locale)
      end
    end
  end

  def append_locale_to_string(string, locale)
    "#{string} - #{locale}"
  end

end