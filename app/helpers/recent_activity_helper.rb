module RecentActivityHelper
  # TODO: Check why this include is necessary
  include GroupsHelper

  ANALYTICS_PARAM = 'ra'

  # Length to truncate activity message to.
  MESSAGE_TRUNCATE_LENGTH = 56

  # Icons to show for each of the activities. These images are expected to
  # reside inside /images/icons.
  ACT_ICONS = {
    RecentActivityConstants::Type::ANNOUNCEMENT_CREATION => 'fa fa-fw fa-bullhorn',
    RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE => 'fa fa-fw fa-bullhorn',
    RecentActivityConstants::Type::TOPIC_CREATION => 'fa fa-fw m-r-xs fa-comment',
    RecentActivityConstants::Type::POST_CREATION => 'fa fa-fw m-r-xs fa-comment',
    RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST => 'fa fa-fw fa-user-plus m-r-xs',
    RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::ADMIN_ADD_MENTOR => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::MENTOR_REQUEST_CREATION => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE => 'fa fa-check fa-fw m-r-xs',
    RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION => 'fa fa-fw m-r-xs fa-times',
    RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL => 'fa fa-fw m-r-xs fa-times',
    RecentActivityConstants::Type::PROGRAM_CREATION => 'fa fa-fw fa-globe m-r-xs',
    RecentActivityConstants::Type::USER_SUSPENSION => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::ADMIN_CREATION => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::USER_ACTIVATION => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::USER_PROMOTION => 'fa fa-fw fa-user m-r-xs',
    RecentActivityConstants::Type::ARTICLE_CREATION => 'fa fa-fw fa-file-text m-r-xs',
    RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL => 'fa fa-fw fa-thumbs-up m-r-xs',
    RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION => 'fa fa-fw m-r-xs fa-comment',
    RecentActivityConstants::Type::GROUP_REACTIVATION => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::GROUP_MEMBER_ADDITION => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::MENTORING_OFFER_CREATION => 'fa fa-fw fa-user-plus m-r-xs',
    RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE => 'fa fa-fw m-r-xs fa-check',
    RecentActivityConstants::Type::MENTORING_OFFER_REJECTION => 'fa fa-fw m-r-xs fa-times',
    RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL => 'fa fa-fw m-r-xs fa-times',
    RecentActivityConstants::Type::FORUM_CREATION => 'fa fa-fw fa-comments',
    RecentActivityConstants::Type::MEETING_CREATED => 'fa fa-fw m-r-xs fa-calendar',
    RecentActivityConstants::Type::MEETING_UPDATED => 'fa fa-fw m-r-xs fa-calendar',
    RecentActivityConstants::Type::MEETING_DECLINED => 'fa fa-fw m-r-xs fa-tasks',
    RecentActivityConstants::Type::MEETING_ACCEPTED => 'fa fa-fw m-r-xs fa-tasks',
    RecentActivityConstants::Type::GROUP_MEMBER_LEAVING => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::GROUP_TERMINATING => 'fa fa-fw m-r-xs fa-users',
    RecentActivityConstants::Type::PROGRAM_EVENT_CREATION => 'fa fa-fw m-r-xs fa-calendar',
    RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE => 'fa fa-fw m-r-xs fa-calendar',
    RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT => 'fa fa-fw m-r-xs fa-check',
    RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT => 'fa fa-fw m-r-xs fa-times',
    RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE => 'fa fa-fw m-r-xs fa-calendar',
    RecentActivityConstants::Type::QA_QUESTION_CREATION => 'fa fa-fw m-r-xs fa-question',
    RecentActivityConstants::Type::QA_ANSWER_CREATION => 'fa fa-fw m-r-xs fa-question',
    RecentActivityConstants::Type::COACHING_GOAL_CREATION => 'icon-situations',
    RecentActivityConstants::Type::COACHING_GOAL_UPDATED => 'icon-situations',
    RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION => 'icon-situations'
  }

  # Calls <code>link_to_user</code> with <code>:src => ANALYTICS_PARAM</code>
  # added to params
  def ra_link_to_user(user, options = {})
    link_to_user(user, options.merge(:params => {:src => ANALYTICS_PARAM}))
  end

  def ra_link_to_member(member, is_visible)
    link_to_member(member, is_visible, {:params => {:src => ANALYTICS_PARAM}})
  end

  # Renders an activity item in the mentoring area.
  def mentoring_area_activity(activity)
    format_recent_activity(activity, nil, true)
  end

  def format_recent_activity(activity, viewing_user = nil, in_mentoring_area = false, options = {})
    begin
      get_ra_object(activity, viewing_user, in_mentoring_area, options)
    rescue => e
      Airbrake.notify("object: #{activity.inspect}: #{e.message}")
      return nil
    end
  end

  def get_text_based_on_grammatical_person(action_type, subject, object, options = {})
    options.reverse_merge!(is_object_present: true)
    key = RecentActivityConstants::Type.get_constant_name_by_value(action_type).to_s.downcase
    is_subject_second_person = subject.is_a?(Member) ? wob_member == subject : current_user == subject

    if options[:is_object_present]
      object = object.member if organization_view?
      is_object_second_person = object.is_a?(Member) ? wob_member == object : current_user == object
    end

    if is_subject_second_person
      "feature.recent_activity.content.gp_#{key}_starts_with_you_html"
    elsif is_object_second_person
      "feature.recent_activity.content.gp_#{key}_ends_with_you_html"
    elsif options[:default_key].present?
      "feature.recent_activity.content.#{options[:default_key]}_html"
    else
      "feature.recent_activity.content.gp_#{key}_html"
    end
  end

  def get_ra_object(activity, viewing_user = nil, in_mentoring_area = false, options = {})
    object = activity.ref_obj
    is_super_console = super_console?
    return unless object # if the object had been deleted

    if program_view?
      # Default viewer to current user when inside a sub program.
      viewing_user ||= current_user
      viewing_program = @current_program
      # Is this possibly a confidential view of the mentoring area by the administrator?
      is_admin_view_of_mentoring_area = in_mentoring_area && viewing_user.is_admin?
    end

    viewing_program ||= object.respond_to?(:program) ? object.program : nil
    if activity.member && viewing_user.try(:program)
      activity_user = activity.get_user(viewing_user.program)
    end

    activity_subject, subject_name =
      if activity.member && organization_view?
        [activity.member, ra_link_to_member(activity.member, check_visibility?(activity.member))]
      elsif activity_user
        [activity_user, ra_link_to_user(activity_user, current_user: viewing_user)]
      end

    if viewing_program.try(:only_career_based_ongoing_mentoring_enabled?)
      can_access_mentor_requests_listing = MentorRequest.has_access?(viewing_user, viewing_program) || viewing_user.can_manage_mentor_requests? || viewing_user.can_send_mentor_request?
      can_access_mentor_offers_listing = viewing_program.mentor_offer_enabled?
    end

    # Is this activity done by activity.user? Activities like announcement creation and
    # user suspension do not contain the real actor.
    is_by_actor = activity.member.present?
    hide_links = options[:hide_links].presence
    action_links = []

    activity_string = case activity.action_type
    when RecentActivityConstants::Type::ANNOUNCEMENT_CREATION
      return unless view_user_is_admin_or_has_common_role(viewing_user, object.recipient_role_names)
      is_by_actor = false
      more_link_url = announcement_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.read_full_announcement".translate, more_link_url)
      action_links << link_to("feature.recent_activity.action.all_announcement".translate, announcements_path(:src => ANALYTICS_PARAM, :root => viewing_program.root))
      "feature.recent_activity.content.announcement_creation_html".translate(:user => subject_name, :title_link => link_to(object.title, more_link_url))

    when RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE
      view_announcement_url = announcement_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.read_full_announcement".translate, view_announcement_url)
      action_links << link_to("feature.recent_activity.action.all_announcement".translate, announcements_path(:src => ANALYTICS_PARAM))
      "feature.recent_activity.content.announcement_update_html".translate(:user => subject_name, :title_link => link_to(object.title, view_announcement_url))

    when RecentActivityConstants::Type::TOPIC_CREATION
      forum = object.forum
      return unless forum.can_be_accessed_by?(viewing_user)

      viewing_program ||= object.program
      more_link_url = forum_topic_path(forum, object, src: ANALYTICS_PARAM, root: viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_conversation".translate, more_link_url)
      "feature.recent_activity.content.topic_creation_html".translate(user: subject_name, link_to_conversation: link_to(object.title, more_link_url))

    when RecentActivityConstants::Type::POST_CREATION
      forum = object.forum
      return unless forum.can_be_accessed_by?(viewing_user)

      viewing_program ||= object.program
      more_link_url = forum_topic_path(forum, object.topic, src: ANALYTICS_PARAM, root: viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_conversation".translate, more_link_url)
      "feature.recent_activity.content.post_creation_v1_html".translate(user: subject_name, link_to_conversation: link_to(object.topic.title, more_link_url))

    when RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST
      "feature.recent_activity.content.create_membership_request_html".translate(
        :user => object.name,
        :program => _program,
        :request_to_join_link => link_to("feature.recent_activity.content.request_to_join".translate, membership_requests_path(:src => ANALYTICS_PARAM, :anchor => "mem_req_#{object.id}", :root => viewing_program.root))
      )

    when RecentActivityConstants::Type::MENTOR_JOIN_PROGRAM
      action_links << ra_link_to_user(activity_user, content_text: "common_text.view_users_profile".translate(user: activity_user.name)) unless (viewing_user == activity_user)
      translation_params = {
        user: subject_name,
        program: _program,
        a_mentor:  _a_mentor
      }
      get_text_based_on_grammatical_person(activity.action_type, activity_subject, nil, default_key: "mentor_join_program", is_object_present: false).translate(translation_params)
    when RecentActivityConstants::Type::ADMIN_ADD_MENTOR
      action_links << ra_link_to_user(activity_user, :content_text => "common_text.view_users_profile".translate(user: activity_user.name)) unless (viewing_user == activity_user)

      if activity_user == viewing_user
        "feature.recent_activity.content.admin_add_mentor_same_user_html".translate(:user => subject_name, :a_mentor => viewing_program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).articleized_term_downcase, :program => _program)
      else
        "feature.recent_activity.content.admin_add_mentor_html".translate(:user => subject_name, :a_mentor => viewing_program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).articleized_term_downcase, :program => _program)
      end

    when RecentActivityConstants::Type::MENTOR_REQUEST_CREATION
      # If the current user sent the request, don't link the RA, else link the
      # RA to mentor_requests index page
      mentor_req = object
      student = mentor_req.student
      if viewing_user != student
        if can_access_mentor_requests_listing
          more_link_url = mentor_requests_path(src: ANALYTICS_PARAM, root: viewing_program.root, mentor_request_id: mentor_req.id).html_safe
          action_links << link_to("feature.recent_activity.action.view_request".translate, more_link_url)
          action_links << ra_link_to_user(student, content_text: "common_text.view_users_profile".translate(user: student.name))
        end
      end
      request_line = "feature.recent_activity.content.mentoring_request_v1".translate(mentoring: viewing_program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase)
      request_line = link_to(request_line, more_link_url) if more_link_url.present?
      activity_object = mentor_req.mentor
      translation_params = {
        user: subject_name,
        mentoring_request: request_line,
        mentor_link: ra_link_to_user(activity_object, current_user: viewing_user)
      }
      get_text_based_on_grammatical_person(activity.action_type, activity_subject, activity_object, default_key: "mentor_request_creation").translate(translation_params)
    when RecentActivityConstants::Type::MENTOR_REQUEST_ACCEPTANCE
      activity_object = object.student
      if object.group
        view_group_url = group_path(object.group, src: ANALYTICS_PARAM, root: viewing_program.root).html_safe
        action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(Mentoring_Area: viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), view_group_url) if object.group.admin_enter_mentoring_connection?(viewing_user, is_super_console)
      end
      translation_params = {
        user: subject_name,
        student_link: ra_link_to_user(activity_object, current_user: viewing_user)
      }
      get_text_based_on_grammatical_person(activity.action_type, activity_subject, activity_object, default_key: "mentor_request_acceptance_v1").translate(translation_params)
    when RecentActivityConstants::Type::MENTOR_REQUEST_REJECTION
      activity_object = object.student
      translation_params = {
        mentoring: viewing_program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase,
        user: subject_name,
        student_link: ra_link_to_user(activity_object, current_user: viewing_user)
      }
      get_text_based_on_grammatical_person(activity.action_type, activity_subject, activity_object, default_key: "mentor_request_rejection_v1").translate(translation_params)
    when RecentActivityConstants::Type::MENTOR_REQUEST_WITHDRAWAL
      activity_object = object.mentor
      translation_params = {
        mentoring: viewing_program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase,
        user: subject_name,
        mentor_link: ra_link_to_user(activity_object, current_user: viewing_user)
      }
      get_text_based_on_grammatical_person(activity.action_type, activity_subject, activity_object, default_key: "mentor_request_withdrawal_v1").translate(translation_params)
    when RecentActivityConstants::Type::PROGRAM_CREATION
      "feature.recent_activity.content.program_creation_html".translate(:owner_link => ra_link_to_user(object.owner, :current_user => viewing_user), :program_link => link_to(object.name, program_root_path(:src => ANALYTICS_PARAM, :root => object.root)), :program => _program)

    when RecentActivityConstants::Type::USER_SUSPENSION
      "feature.recent_activity.content.user_suspension_v1_html".translate(:user => subject_name, :target_user => ra_link_to_user(object), :program => viewing_program.name)

    when RecentActivityConstants::Type::USER_ACTIVATION
      action_links << ra_link_to_user(object, :content_text => "common_text.view_users_profile".translate(user: object.name)) unless (viewing_user == object)

      "feature.recent_activity.content.user_activation_html".translate(:user => subject_name, :target_user => ra_link_to_user(object))

    when RecentActivityConstants::Type::USER_PROMOTION
      picture_of_user = object
      action_links << ra_link_to_user(object, :content_text => "common_text.view_users_profile".translate(user: object.name)) unless (viewing_user == object)

      "feature.recent_activity.content.user_promotion_html".translate(user: ra_link_to_user(object, current_user: viewing_user, verb: true), role: object.formatted_role_names(articleize: true, no_capitalize: true))

    when RecentActivityConstants::Type::ARTICLE_CREATION
      action_links << link_to("feature.recent_activity.action.read_article".translate(:article => _article), article_path(object, :src => ANALYTICS_PARAM))
      action_links << link_to("feature.recent_activity.action.browse_all_articles".translate(:articles => _articles), articles_path, :src => ANALYTICS_PARAM)

      "feature.recent_activity.content.article_creation_html".translate(:user => subject_name, :a_article => _a_article, :title_link => link_to(object.title, article_path(object, :src => ANALYTICS_PARAM)))

    when RecentActivityConstants::Type::ARTICLE_MARKED_AS_HELPFUL
      article = object
      action_links << link_to("feature.recent_activity.action.read_article".translate(:article => _article), article_path(article, :src => ANALYTICS_PARAM))
      translation_params = {
        :user => subject_name,
        :article => _article,
        :article_link => link_to(article.title, article_path(article, :src => ANALYTICS_PARAM))
      }

      if viewing_user.member.authored?(article)
        "feature.recent_activity.content.your_article_marked_as_helpful_html".translate(translation_params)
      else
        "feature.recent_activity.content.article_marked_as_helpful_html".translate(translation_params)
      end

    when RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION
      comment = object
      published_program = viewing_program || comment.publication.program
      article = comment.article
      view_article_url = article_path(article, :root => published_program.root, :src => ANALYTICS_PARAM)
      view_comment_url = article_path(article, :anchor => "comment_#{comment.id}", :root => published_program.root, :src => ANALYTICS_PARAM)

      action_links << link_to("feature.recent_activity.action.read_comment".translate, view_comment_url)
      action_links << link_to("feature.recent_activity.action.read_article".translate(:article => _article), view_article_url)
      translation_params = {
        :user => subject_name,
        :article => _article,
        :comment_link => link_to("feature.recent_activity.content.comment".translate, view_comment_url),
        :article_link => link_to(article.title, view_article_url)
      }

      if viewing_user.member.authored?(article)
        "feature.recent_activity.content.your_article_comment_creation_html".translate(translation_params)
      else
        "feature.recent_activity.content.article_comment_creation_html".translate(translation_params)
      end

    when RecentActivityConstants::Type::ADMIN_CREATION
      "feature.recent_activity.content.admin_creation_html".translate(:user => subject_name, :admin => _admin)

    when RecentActivityConstants::Type::GROUP_REACTIVATION
       return unless is_admin_view_of_mentoring_area || object.has_member?(viewing_user)

      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)) if object.admin_enter_mentoring_connection?(viewing_user, is_super_console)

      "feature.recent_activity.content.group_reactivation_html".translate(:user => subject_name, :group_link => group_member_ra_links(object, viewing_user))

    when RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE
      return unless is_admin_view_of_mentoring_area || object.has_member?(viewing_user)

      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)) if object.admin_enter_mentoring_connection?(viewing_user, is_super_console)

      "feature.recent_activity.content.group_change_expirity_date_html".translate(:user => subject_name, :group_link => group_member_ra_links(object, viewing_user))

    when RecentActivityConstants::Type::GROUP_MEMBER_ADDITION
      return unless is_admin_view_of_mentoring_area || object.has_member?(viewing_user)
      # In case of self view, subject_name is "You". So, we need to downcase it
      subject_name = subject_name.downcase if (viewing_user == activity_user)
      view_mentoring_area_url = group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << ra_link_to_user(activity_user, :content_text => "common_text.view_users_profile".translate(user: activity_user.name)) unless (viewing_user == activity_user)
      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), view_mentoring_area_url) if object.admin_enter_mentoring_connection?(viewing_user, is_super_console)
      translation_params = {
        :admin => _Admin,
        :user => subject_name,
        :mentoring_connection => link_to(viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, view_mentoring_area_url)
      }

      is_by_actor = false
      if viewing_user == activity_user
        "feature.recent_activity.content.own_group_member_addition_html".translate(translation_params)
      else
        "feature.recent_activity.content.group_member_addition_html".translate(translation_params)
      end

    when RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL
      return unless is_admin_view_of_mentoring_area || object.has_member?(viewing_user)
      # In case of self view, subject_name is "You". So, we need to downcase it
      is_by_actor = false
      view_mentoring_area_url = group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), view_mentoring_area_url) if object.admin_enter_mentoring_connection?(viewing_user, is_super_console)
      action_links << ra_link_to_user(activity_user, :content_text => "common_text.view_users_profile".translate(user: activity_user.name)) unless (viewing_user == activity_user)

      "feature.recent_activity.content.group_member_removal_html".translate(
        :admin => _Admin,
        :user => viewing_user == activity_user ? subject_name.downcase : subject_name,
        :mentoring_connection => link_to(viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root))
      )

    when RecentActivityConstants::Type::GROUP_MEMBER_LEAVING
      group = object
      self_view = (activity_user == viewing_user)
      return unless self_view || is_admin_view_of_mentoring_area || group.has_member?(viewing_user)

      "feature.recent_activity.content.group_member_leaving_html".translate(:user => subject_name, :mentoring_connection => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term, :group => link_to_if(group.admin_enter_mentoring_connection?(viewing_user, is_super_console), group.name, group_path(group, :src => ANALYTICS_PARAM, :root => viewing_program.root)))

    when RecentActivityConstants::Type::GROUP_TERMINATING
      group = object
      self_view = (activity_user == viewing_user)
      return unless self_view || is_admin_view_of_mentoring_area || group.has_member?(viewing_user)

      "feature.recent_activity.content.group_terminating_html".translate(:mentoring_connection => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term, :group => link_to_if(group.admin_enter_mentoring_connection?(viewing_user, is_super_console), group.name, group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)))

    when RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION
      return unless viewing_user.is_admin? || object.has_member?(viewing_user)
      offered_to_user = User.find(activity.message.to_i)
      # The user to whom the mentoring is offered is stored as a marshal as *activity.message*
      offered_to_name = ra_link_to_user(offered_to_user, :current_user => viewing_user)
      # In case of self view, offered_to_name is "You". So, we need to downcase it
      offered_to_name = offered_to_name.downcase if (viewing_user == offered_to_user)
      is_by_actor = false
      view_mentoring_area_url = group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => viewing_program.present? ? viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term : _Mentoring_Connection), view_mentoring_area_url) if object.admin_enter_mentoring_connection?(viewing_user, is_super_console)
      action_links << ra_link_to_user(activity_user, :content_text => "common_text.view_users_profile".translate(user: activity_user.name)) unless (viewing_user == activity_user)

      "feature.recent_activity.content.mentoring_offer_direct_addition_html".translate(:user => subject_name, :offered_to_name => offered_to_name, :mentoring_connection => link_to_if(object.admin_enter_mentoring_connection?(viewing_user, is_super_console), viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, group_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)))

    when RecentActivityConstants::Type::MENTORING_OFFER_CREATION
      offer = object
      mentor = offer.mentor
      student = offer.student

      if viewing_user == student
        if can_access_mentor_offers_listing
          offer_path = mentor_offers_path(:src => ANALYTICS_PARAM, :root => viewing_program.root)
          action_links << link_to("feature.recent_activity.action.view_offer".translate, offer_path)
          action_links << ra_link_to_user(mentor, :content_text => "common_text.view_users_profile".translate(user: mentor.name))
        end
        mentoring_offer_text = "feature.recent_activity.content.mentoring_offer_v1".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase)
        mentoring_offer_text = link_to(mentoring_offer_text, offer_path) if offer_path.present?
      end

      if viewing_user == student
        "feature.recent_activity.content.mentoring_offer_creation_student_html".translate(:mentoring_offer => mentoring_offer_text, :mentor => ra_link_to_user(mentor))
      elsif viewing_user == mentor
        "feature.recent_activity.content.mentoring_offer_creation_mentor_v1_html".translate(:student => ra_link_to_user(student), :mentoring_connection => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)
      else
        "feature.recent_activity.content.mentoring_offer_creation_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :mentor => ra_link_to_user(mentor), :student => ra_link_to_user(student))
      end

    when RecentActivityConstants::Type::MENTORING_OFFER_ACCEPTANCE
      offer = object
      mentor = offer.mentor
      student = offer.student

      more_link_url = group_path(offer.group, src: ANALYTICS_PARAM, root: viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_mentoring_connection".translate(:mentoring_connection => viewing_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase), more_link_url) if offer.group.admin_enter_mentoring_connection?(viewing_user, is_super_console)

      if viewing_user == student
        "feature.recent_activity.content.mentoring_offer_acceptance_student_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :mentor => ra_link_to_user(mentor))
      elsif viewing_user == mentor
        "feature.recent_activity.content.mentoring_offer_acceptance_mentor_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student))
      else
        "feature.recent_activity.content.mentoring_offer_acceptance_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student), :mentor => ra_link_to_user(mentor))
      end

    when RecentActivityConstants::Type::MENTORING_OFFER_REJECTION
      offer = object
      mentor = offer.mentor
      student = offer.student

      if viewing_user == student
        "feature.recent_activity.content.mentoring_offer_rejection_student_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :mentor => ra_link_to_user(mentor))
      elsif viewing_user == mentor
        "feature.recent_activity.content.mentoring_offer_rejection_mentor_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student))
      else
        "feature.recent_activity.content.mentoring_offer_rejection_v1_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student), :mentor => ra_link_to_user(mentor))
      end

    when RecentActivityConstants::Type::MENTOR_OFFER_WITHDRAWAL
      offer = object
      mentor = offer.mentor
      student = offer.student

      if viewing_user == student
        "feature.recent_activity.content.mentor_offer_withdrawal_student_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :mentor => ra_link_to_user(mentor))
      elsif viewing_user == mentor
        "feature.recent_activity.content.mentor_offer_withdrawal_mentor_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student))
      else
        "feature.recent_activity.content.mentor_offer_withdrawal_html".translate(:mentoring => object.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase, :student => ra_link_to_user(student), :mentor => ra_link_to_user(mentor))
      end

    when RecentActivityConstants::Type::FORUM_CREATION
      return unless view_user_is_admin_or_has_common_role(viewing_user, object.access_role_names) && object.program.forums_enabled?
      view_forum_path = forum_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.visit_the_forum".translate, view_forum_path)

      "feature.recent_activity.content.forum_creation_html".translate(:admin => _Admin, :forum_link => link_to(object.name, view_forum_path))

    when RecentActivityConstants::Type::MEETING_CREATED
      meeting_string, action_links = get_meeting_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "feature.recent_activity.content.created".translate)
      meeting_string.nil? ? return : meeting_string

    when RecentActivityConstants::Type::MEETING_UPDATED
      meeting_string, action_links = get_meeting_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "feature.recent_activity.content.updated".translate)
      meeting_string.nil? ? return : meeting_string

    when RecentActivityConstants::Type::MEETING_DECLINED
      meeting_string, action_links = get_meeting_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "feature.recent_activity.content.declined".translate)
      meeting_string.nil? ? return : meeting_string

    when RecentActivityConstants::Type::MEETING_ACCEPTED
      meeting_string, action_links = get_meeting_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "feature.recent_activity.content.accepted".translate)
      meeting_string.nil? ? return : meeting_string

    when RecentActivityConstants::Type::PROGRAM_EVENT_CREATION
      return unless view_user_is_admin_or_in_view(viewing_user, object)
      program_event_string, action_links = get_program_event_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "display_string.created".translate, hide_links)
      program_event_string.nil? ? return : program_event_string
    when RecentActivityConstants::Type::PROGRAM_EVENT_UPDATE
      return unless view_user_is_admin_or_in_view(viewing_user, object)
      program_event_string, action_links = get_program_event_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "display_string.updated".translate, hide_links)
      program_event_string.nil? ? return : program_event_string
    when RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT
      return unless view_user_is_admin_or_in_view(viewing_user, object)
      program_event_string, action_links = get_program_event_invite_status_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, viewing_user == activity_user ? "feature.program_event.content.are_attending".translate : "feature.program_event.content.is_attending".translate, hide_links)
      program_event_string.nil? ? return : program_event_string
    when RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT
      return unless view_user_is_admin_or_in_view(viewing_user, object)
      program_event_string, action_links = get_program_event_invite_status_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, viewing_user == activity_user ? "feature.program_event.content.are_not_attending".translate : "feature.program_event.content.is_not_attending".translate, hide_links)
      program_event_string.nil? ? return : program_event_string
    when RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE
      return unless view_user_is_admin_or_in_view(viewing_user, object)
      program_event_string, action_links = get_program_event_invite_status_ra_content(activity, object, activity_user, viewing_user, subject_name, action_links, "feature.program_event.content.may_be_attending".translate, hide_links)
      program_event_string.nil? ? return : program_event_string

    when RecentActivityConstants::Type::QA_QUESTION_CREATION
      viewing_program ||= object.program
      qa_question_link_url = qa_question_path(object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_question".translate, qa_question_link_url)

      "feature.recent_activity.content.qa_question_creation_html".translate(:user => subject_name, :question_link => link_to(object.summary, qa_question_link_url))

    when RecentActivityConstants::Type::QA_ANSWER_CREATION
      qa_question = object.qa_question
      return unless qa_question.follow?(viewing_user)
      viewing_program ||= qa_question.program
      qa_answer_link_url = qa_question_path(qa_question, :src => ANALYTICS_PARAM, :root => viewing_program.root, :scroll_to => "qa_answer_#{object.id}")
      qa_question_link_url = qa_question_path(object.qa_question, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_answer".translate, qa_answer_link_url)

      if viewing_user == qa_question.user
        "feature.recent_activity.content.qa_answer_creation_same_user_html".translate(:user => subject_name, :question_link => link_to(qa_question.summary, qa_question_link_url))
      else
        "feature.recent_activity.content.qa_answer_creation_html".translate(:user => subject_name, :question_link => link_to(qa_question.summary, qa_question_link_url))
      end
    when RecentActivityConstants::Type::COACHING_GOAL_CREATION
      obj_group = object.group
      viewing_program ||= obj_group.program
      view_goal_url = group_coaching_goal_path(obj_group, object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_goal_details".translate, view_goal_url) unless hide_links

      "feature.recent_activity.content.coaching_goal_creation_html".translate(:user => subject_name, :goal_link => link_to(object.title, view_goal_url))

    when RecentActivityConstants::Type::COACHING_GOAL_UPDATED
      obj_group = object.group
      viewing_program ||= obj_group.program
      view_goal_url = group_coaching_goal_path(obj_group, object, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_goal_details".translate, view_goal_url) unless hide_links

      "feature.recent_activity.content.coaching_goal_updated_html".translate(
        :user => subject_name,
        :goal_link => link_to(object.title, view_goal_url),
        :date => DateTime.localize(object.due_date, format: :full_display_no_time)
      )

    when RecentActivityConstants::Type::COACHING_GOAL_ACTIVITY_CREATION
      coaching_goal_activity = object
      coaching_goal_activity_message = coaching_goal_activity.message
      coaching_goal = object.coaching_goal
      obj_group = coaching_goal.group
      viewing_program ||= obj_group.program
      view_goal_url = group_coaching_goal_path(obj_group, coaching_goal, :src => ANALYTICS_PARAM, :root => viewing_program.root)
      action_links << link_to("feature.recent_activity.action.view_goal_details".translate, view_goal_url) unless hide_links && !obj_group.admin_enter_mentoring_connection?(viewing_program)
      get_coaching_goal_ra_title(coaching_goal, coaching_goal_activity, view_goal_url, activity_user == viewing_user, subject_name)

    else
      raise "feature.recent_activity.content.invalid_ra".translate
    end

    activity_string = content_tag(:div, activity_string, class: "whitespace-nowrap truncate-with-ellipsis")
    picture_of_user ||= activity_user
    content_tag(:div, :class => "list-group-item activity_summary media list_content no-margins b-b", :id => "activity_#{activity.id}") do
        str = content_tag(:div, :class => 'pull-left no-margins') do
          if is_by_actor
            picture_of_user ? user_picture(picture_of_user, {:size => :small, :new_size => :tiny, :no_name => true, :user_name => subject_name}, {:class => "img-circle m-l-xs m-r-sm" , height: 21, width: 21}) : member_picture(activity.member, {:size => :small, :new_size => :tiny, :no_name => true}, {:class => "img-circle  p-l-xxs p-r-xs" , height: 21, width: 21})
          else
            content_tag(:span, content_tag(:i, "", class: "fa-lg m-r-xs #{ACT_ICONS[activity.action_type]}"), class: "pull-left m-l-xs m-r-xs #{hidden_on_mobile}") +
            content_tag(:span, content_tag(:i, "", class: "fa-lg m-r-xs #{ACT_ICONS[activity.action_type]}", :width => "35px"), :class => "#{hidden_on_web}")
          end
        end

        separator = content_tag(:span, circle_separator, :class => hidden_on_mobile)
        program_list_content = ""
        if organization_view?
          program_list = []
          program_text = activity.programs.count > 1 ? _programs : _program
          activity.programs.ordered.collect do |program|
            program_list << link_to(
                              program.name,
                              program_root_path(:root => program.root),
                              :class => 'prog_label_ra label label-default m-xs m-t-0',
                              :title => program.name
                              )
          end

          program_list_content = content_tag(:div, :class => "text-muted small clearfix m-t-sm") do
            safe_join(program_list, "")
          end
      end

      str << content_tag(:div, :class => 'act_content whitespace-nowrap truncate-with-ellipsis') do
        content_tag(:div, activity_string) +
          content_tag(:div, :class => 'clearfix') do
          icon_and_date = get_safe_string
          icon_and_date << embed_icon(ACT_ICONS[activity.action_type]) if is_by_actor
          icon_and_date << content_tag(:span, :class => 'small') do

            date_and_actions = []
            if in_mentoring_area
              date_str = formatted_time_in_words(activity.created_at)
              date_and_actions << content_tag(:span, date_str, :class => 'text-muted')
            else
              # Get rid of 'about' prefix in the time string.
              date_str = time_ago_in_words(activity.created_at).gsub('about ', '')
              date_and_actions << content_tag(:span, "feature.recent_activity.content.about_time_ago".translate(:time => date_str), :class => 'text-muted')
            end

            if action_links.any?
              date_and_actions << content_tag(:span, safe_join(action_links.first(1), separator), :class => "#{hidden_on_mobile} m-l-xs")
            end

            safe_join(date_and_actions, separator)
          end
        end + program_list_content
      end
    end
  end

  def group_member_ra_links(group, user)
    if group.has_mentor?(user)
      group_members = ["display_string.you".translate] + group.students.collect {|student| ra_link_to_user(student, :current_user => user)}
      mentoring_connection_string = content_tag(:span, "feature.recent_activity.content.the_mentoring_connection_between_members_html".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, :group_members => to_sentence_sanitize(group_members)), :class => 'has-before')
    else
      mentor_links = to_sentence_sanitize(group.mentors.collect{|mentor| ra_link_to_user(mentor, :current_user => user)})
      mentoring_connection_string = "feature.recent_activity.content.your_mentoring_connection_with_link_html".translate(:mentoring_connection => group.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase, :mentor_links => mentor_links)
    end
  end

  def get_meeting_ra_content(activity, meeting, activity_user, viewing_user, subject_user_name, action_links, meeting_context)
    member = viewing_user.member
    viewer_member_meeting = meeting.member_meetings.find{|mm| mm.member_id == member.id}
    return nil, nil if viewer_member_meeting.nil?

    meeting_link = member_path(viewing_user.member, :tab => MembersController::ShowTabs::AVAILABILITY, :meeting_id => meeting.id, :root => meeting.program.root, :src => ANALYTICS_PARAM).html_safe
    action_links << link_to("feature.recent_activity.action.view_meeting_v1".translate(:meeting => meeting.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase), meeting_link)

    if meeting.group.present?
      view_group_url = group_path(meeting.group, :src => ANALYTICS_PARAM, :root => meeting.program.root).html_safe
      action_links << link_to("feature.recent_activity.action.visit_mentoring_area_v1".translate(:Mentoring_Area => meeting.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term), view_group_url)
    end

    unless (viewer_member_meeting.accepted? || viewer_member_meeting.rejected?)
      action_links << get_safe_string + "feature.recent_activity.content.attending_dash".translate + link_to("display_string.Yes".translate, (@group.nil? ? update_from_guest_meeting_path(meeting, :attending => MemberMeeting::ATTENDING::YES, :member_id => member.id, :all_meetings => true).html_safe : update_from_guest_meeting_path(meeting, :group_id => @group.id, :attending => MemberMeeting::ATTENDING::YES, :member_id => member.id, :all_meetings => true).html_safe)) +
                                      link_to("display_string.No".translate, (@group.nil? ? update_from_guest_meeting_path(meeting, :attending => MemberMeeting::ATTENDING::NO, :member_id => member.id, :all_meetings => true).html_safe : update_from_guest_meeting_path(meeting, :group_id => @group.id, :attending => MemberMeeting::ATTENDING::NO, :member_id => member.id, :all_meetings => true).html_safe), :class => "divider-vertical") if (viewing_user.member != meeting.owner && activity_user != viewing_user && !meeting.archived?)
    end

    meeting_activity_message = content_tag(:i, truncate(activity.message, :length => MESSAGE_TRUNCATE_LENGTH))
    return "feature.recent_activity.content.meeting_content_v1_html".translate(:meeting => meeting.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase, :user => subject_user_name, :meeting_context => meeting_context, :meeting_activity_message => meeting_activity_message), action_links
  end

  def get_program_event_ra_content(activity, program_event, activity_user, viewing_user, subject_user_name, action_links, program_event_context, hide_links)
    if program_view?
      is_attendee = program_event.has_current_user_as_attendee?(viewing_user)
    end
    action_links << link_to("feature.program_event.action.view_event".translate, program_event_path(program_event, :root => program_event.program.root, :src => ANALYTICS_PARAM).html_safe) unless hide_links
    if program_view? && is_attendee && !program_event.archived? && viewing_user.member != program_event.user && activity_user != viewing_user && !program_event.draft? && !program_event.archived?
      rsvp_actions = ("#{'feature.program_event.label.is_attending'.translate} - "+ link_to('display_string.Yes'.translate, "#", :id => "invite_response_attending_ra_#{activity.id}_#{program_event.id}", :class => "p-l-xxs p-r-xxs", "data-toggle" => "modal", "data-target" => "#modal_invite_response_attending_ra_#{activity.id}_#{program_event.id}") + link_to('display_string.No'.translate, "#", :id => "invite_response_not_attending_ra_#{activity.id}_#{program_event.id}", :class => "p-l-xxs p-r-xxs b-l" , "data-toggle" => "modal", "data-target" => "#modal_invite_response_not_attending_ra_#{activity.id}_#{program_event.id}") + link_to('display_string.Maybe'.translate, "#", :id => "invite_response_maybe_attending_ra_#{activity.id}_#{program_event.id}" , :class => "p-l-xxs p-r-xxs b-l", "data-toggle" => "modal", "data-target" => "#modal_invite_response_maybe_attending_ra_#{activity.id}_#{program_event.id}")).html_safe

      action_links << rsvp_actions + javascript_tag("jQuery('body').append('#{j(render(:partial => "program_events/invite_response_popup", :locals => {:program_event => program_event, :src => "ra_#{activity.id}"}))}')")
    end
    return "feature.program_event.content.event_activity_html".translate(
             :user => subject_user_name,
             :program_event_context => program_event_context,
             :program_event_title_link => link_to(program_event.title, program_event_path(program_event))
            ), action_links
  end

  def get_program_event_invite_status_ra_content(activity, program_event, activity_user, viewing_user, subject_user_name, action_links, program_event_context, hide_links)
    action_links << link_to("feature.program_event.action.view_event".translate, program_event_path(program_event, :root => program_event.program.root, :src => ANALYTICS_PARAM)) unless hide_links
    return "feature.program_event.content.event_activity_html".translate(:user => subject_user_name, :program_event_context => program_event_context, :program_event_title_link => link_to(program_event.title, program_event_path(program_event))), action_links
  end

  # options[:for_all] should be passed when the empty object_role_names mean all roles of program.
  def view_user_is_admin_or_has_common_role(viewing_user, object_role_names, options = {})
    (options[:for_all] && object_role_names.empty?) || viewing_user.is_admin? || (viewing_user.role_names & object_role_names).any?
  end

  def view_user_is_admin_or_in_view(viewing_user, program_event)
    viewing_user.is_admin? || program_event.has_current_user_as_attendee?(viewing_user)
  end

  def get_coaching_goal_ra_title(coaching_goal, coaching_goal_activity, show_page_path, self_view, subject_user_name)
    content = get_safe_string
    if coaching_goal_activity.progress_value.present?
      content << "feature.recent_activity.content.process_updated_by_persent_html".translate(:user => subject_user_name, :coaching_goal => link_to(coaching_goal.title, show_page_path), :percent => coaching_goal_activity.progress_value.to_i)
    else
      content << if self_view
        "feature.recent_activity.content.own_comment_on_the_goal_html".translate(:user => subject_user_name, :coaching_goal => link_to(coaching_goal.title, show_page_path))
      else
        "feature.recent_activity.content.comment_on_the_goal_html".translate(:user => subject_user_name, :coaching_goal => link_to(coaching_goal.title, show_page_path))
      end
    end
    content
  end
end
