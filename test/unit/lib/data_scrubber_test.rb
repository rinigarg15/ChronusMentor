require_relative './../../test_helper.rb'

class DataScrubberTest < ActionController::TestCase
  def setup
    super
    @program = programs(:albers)
    @admin = users(:f_admin)
    @mentor = users(:f_mentor)
    @student = users(:f_student)
    @mentor.update_attribute :program_notification_setting, UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    @data_scrubber = DataScrubber.new(@program)
  end

  def test_models_should_not_have_dependencies
    DataScrubber::INDEPENDENT_OBJECTS.each do |klass|
      [:has_one, :has_many].each do |association_type|
        assert klass.reflect_on_all_associations(association_type).all? { |association| association.options[:dependent].empty? }, "New #{association_type} dependencies are added to #{klass}. Pass object_ids to the corresponding scrub method in the scrubber."
      end
    end
  end

  def test_independent_models_should_not_have_counter_culture
    DataScrubber::INDEPENDENT_OBJECTS.each { |klass| assert_empty klass.after_commit_counter_cache }
  end

  def test_independent_models_should_not_have_counter_cache
    DataScrubber::INDEPENDENT_OBJECTS.each do |klass|
      assert_empty klass.reflect_on_all_associations.select { |assoc| assoc.options[:counter_cache].present? }
    end
  end

  def test_scrub_announcements
    announcement = announcements(:assemble)
    create_job_log(user: @mentor, object: announcement)
    create_pending_notification(ref_obj: announcement)
    create_push_notification(ref_obj: announcement)
    create_recent_activity(member: @admin.member, ref_obj: announcement, action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION)
    announcement.vulnerable_content_logs.create!(original_content: "original", sanitized_content: "sanitized", member_id: @mentor.member_id, ref_obj_column: :body)
    announcement.update_attributes(body: "Updated body!!")

    assert_scrub(:scrub_announcements, announcement)
  end

  def test_scrub_qa_questions
    qa_question = qa_questions(:what)
    create_flag(content: qa_question)
    create_recent_activity(member: qa_question.user.member, ref_obj: qa_question, action_type: RecentActivityConstants::Type::QA_QUESTION_CREATION)

    assert_scrub(:scrub_qa_questions, qa_question)
  end

  def test_scrub_qa_answers
    user = users(:f_admin)
    program = programs(:ceg)
    qa_answer = qa_answers(:for_question_what)
    create_flag(content: qa_answer)
    qa_answer.ratings.create!(rating: 1, user_id: @student.id )
    create_recent_activity(member: qa_answer.user.member, ref_obj: qa_answer, action_type: RecentActivityConstants::Type::QA_ANSWER_CREATION)

    #Testing has_many association & dependent destroy is tested by assert_scrub method
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::QA_ANSWER_CREATION, RecentActivityConstants::Type::AUTO_EMAIL_NOTIFICATION]
    assert_difference "PendingNotification.count", 2 do
        action_types.each do |action_type|
            pending_notifications << qa_answer.pending_notifications.create!(
            ref_obj_creator: user,
            ref_obj: qa_answer,
            program: program,
            action_type:  action_type)
        end
    end
    assert_equal pending_notifications, qa_answer.pending_notifications
    assert_scrub(:scrub_qa_answers, qa_answer)
  end

  def test_scrub_program_events
    program_event = program_events(:birthday_party)
    program_event.event_invites.create!(:user => @mentor, :status => EventInvite::Status::YES)
    program_event.event_invites.create!(:user => @student, :status => EventInvite::Status::YES)
    program_event.vulnerable_content_logs.create!(original_content: "original", sanitized_content: "sanitized", member_id: @mentor.member_id, ref_obj_column: :descrtiption)
    create_recent_activity(member: program_event.user.member, ref_obj: program_event, action_type: RecentActivityConstants::Type::PROGRAM_EVENT_CREATION)
    program_event.role_references.create!(role: @program.roles.first)
    program_event.update_attributes(description: "hello", email_notification: false)

    #Testing has_many association & dependent destroy is tested by assert_scrub method
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE]
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << program_event.pending_notifications.create!(
            ref_obj_creator: program_event.user,
            ref_obj: program_event,
            program: program_event.program,
            action_type: action_type)
      end
    end
    assert_equal pending_notifications, program_event.pending_notifications
    assert_scrub(:scrub_program_events, program_event)
  end

  def test_scrub_survey_answers
    survey = surveys(:progress_report)
    survey.update_total_responses!
    assert_equal 2, survey.total_responses
    assert_scrub(:scrub_survey_answers, survey, associations: :survey_answers)
    assert_equal 0, survey.reload.total_responses
  end

  def test_scrub_recent_activities
    recent_activity1 = create_recent_activity(member: @mentor.member, action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION)
    recent_activity2 = create_recent_activity(member: @mentor.member, ref_obj: groups(:mygroup), action_type: RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY)

    assert_scrub(:scrub_recent_activities, recent_activity1, reject_associations: [:connection_activities])
    assert_scrub(:scrub_recent_activities, recent_activity2)
  end

  def test_scrub_posts
    topic = create_topic
    post = create_post(topic: topic)
    @mentor.job_logs.create!(loggable_object: post, action_type: RecentActivityConstants::Type::POST_CREATION)
    create_pending_notification(ref_obj: post, action_type: RecentActivityConstants::Type::POST_CREATION)
    create_viewed_object(ref_obj: post, user: @mentor)
    create_flag(content: post)

    assert_scrub(:scrub_posts, post)
  end

  def test_scrub_topics
    topic = create_topic
    create_post(topic: topic)
    create_pending_notification(ref_obj: topic, action_type: RecentActivityConstants::Type::TOPIC_CREATION)
    topic.subscribe_user(@mentor)
    topic.vulnerable_content_logs.create!(original_content: "original", sanitized_content: "sanitized", member_id: @mentor.member_id, ref_obj_column: :body)

    assert_scrub(:scrub_topics, topic)
  end

  def test_scrub_forums
    forum = forums(:forums_1)
    topic = create_topic(user: @admin, forum: forum)
    create_recent_activity(:action_type => RecentActivityConstants::Type::FORUM_CREATION, :ref_obj => forum, :target => RecentActivityConstants::Target::ADMINS)

    assert_scrub(:scrub_forums, forum)
  end

  def test_scrub_articles
    article = articles(:economy)
    create_pending_notification(ref_obj: article, action_type: RecentActivityConstants::Type::ARTICLE_CREATION)
    create_recent_activity(:action_type => RecentActivityConstants::Type::ARTICLE_CREATION, :ref_obj => article, :target => RecentActivityConstants::Target::ALL)
    create_flag(content: article)
    article.ratings.create!(rating: 1, user_id: @admin.id )

    assert_scrub(:scrub_articles, article)
  end

  def test_scrub_resources
    resource = create_resource(title: "test", content: "content", programs: { @program => [@program.roles.first.id] })
    resource.ratings.create!(rating: 1, user_id: @admin.id )

    assert_scrub(:scrub_resources, resource)
  end

  def test_scrub_program_invitations
    invitation = program_invitations(:mentor)
    invitation.vulnerable_content_logs.create!(original_content: "original", sanitized_content: "sanitized", member_id: @mentor.member_id, ref_obj_column: :message)
    invitation.job_logs.create!(loggable_object: cm_campaigns(:cm_campaigns_3), action_type: "Sending Invitation")
    assert_scrub(:scrub_program_invitations, invitation)
  end

  def test_scrub_program_invitation_campaign_analytics
    campaign_message = cm_campaign_messages(:cm_campaign_messages_3)
    assert_scrub(:scrub_program_invitation_campaign_analytics, campaign_message, associations: [:emails, :campaign_message_analyticss])
  end

  def test_scrub_admin_messages
    admin_message = messages(:first_campaigns_admin_message)
    create_push_notification(ref_obj: admin_message)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(AdminMessage, [admin_message.id]).once
    assert_scrub(:scrub_admin_messages, admin_message)
  end

  private

  def assert_scrub(scrubber_method, object, options = {})
    association_map = fetch_association_map(object.class)
    associations = options[:associations].present? ? Array(options[:associations]) : fetch_dependent_non_through_associations(association_map)
    associations -= options[:reject_associations].to_a
    association_counts_array = validate_and_populate_association_count(object, associations, association_map)
    association_counts_array += populate_counter_cache_association_count(object)
    association_counts_array << ["#{object.class.name}.count", -1] if options[:associations].blank?
    assert_no_emails do
      assert_differences association_counts_array do
        @data_scrubber.send(scrubber_method, object.id)
      end
    end
  end

  def validate_and_populate_association_count(object, associations, association_map)
    associations.map do |association|
      # has_one associations return object instead of relation. Hence Array()
      association_count = Array(object.send(association).reload).size
      assert_not_equal 0, association_count, "No #{association} are associated with the object. Manually create associated objects."
      [
        (association_map[association].macro == :has_one) ? "Array(object.reload_#{association}).size" : "object.send(:#{association}).reload.size",
        -association_count
      ]
    end
  end

  def populate_counter_cache_association_count(object)
    object.class.after_commit_counter_cache.collect do |counter_cache_association|
      ["object.#{counter_cache_association.relation.first}.reload.#{counter_cache_association.counter_cache_name}", -1]
    end
  end

  def fetch_association_map(klass)
    klass.reflect_on_all_associations.inject({}) do |association_map, association|
      if [:has_many, :has_one].include?(association.macro)
        association_map[association.name] = association
      end
      association_map
    end
  end

  def fetch_dependent_non_through_associations(association_map)
    association_map.values.select do |association|
      association.options[:dependent].present? && !association.options[:through]
    end.map(&:name)
  end
end