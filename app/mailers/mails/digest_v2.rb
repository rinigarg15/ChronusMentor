class DigestV2 < ChronusActionMailer::Base
  @mailer_attributes = {
    :uid                    => 'y0o38izo', # rand(36**8).to_s(36)
    :category               => EmailCustomization::NewCategories::Type::DIGEST_AND_WEEKLY_UPDATES,
    :title                  => Proc.new{|program| "email_translations.digest_v2.title".translate(program.return_custom_term_hash) },
    :description            => Proc.new{|program| "email_translations.digest_v2.description_html".translate(program.return_custom_term_hash) },
    :subject                => Proc.new{ "email_translations.digest_v2.subject.default".translate },
    :campaign_id            => CampaignConstants::DIGEST_V2_CAMPAIGN_MAIL_ID, # note : resolves to 'facilitation_message_mail'
    :disable_customization  => true,
    :user_states            => [User::Status::ACTIVE, User::Status::PENDING],
    :level                  => EmailCustomization::Level::PROGRAM,
    :listing_order          => 1,
    :no_header_salutation   => true,
    :no_widget_signature    => true,
    :layout                 => DIGEST_V2_EMAIL_LAYOUT
  }

  MEMBERSHIP_PENDING_NOTIFICATION_TO_PRIORITY = {
    RecentActivityConstants::Type::USER_SUSPENSION                  => 0,
    RecentActivityConstants::Type::GROUP_MEMBER_LEAVING             => 1,
    RecentActivityConstants::Type::GROUP_MEMBER_UPDATE              => 2,
    RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE         => 3,
    RecentActivityConstants::Type::POST_CREATION                    => 4,
    RecentActivityConstants::Type::TOPIC_CREATION                   => 5,
    RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION    => 6
  }

  USER_PENDING_NOTIFICATION_BY_PRIORITY = [
    RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
    RecentActivityConstants::Type::ANNOUNCEMENT_UPDATE,
    RecentActivityConstants::Type::POST_CREATION,
    RecentActivityConstants::Type::ARTICLE_CREATION,
    RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION,
    RecentActivityConstants::Type::QA_ANSWER_CREATION
  ]

  PROFILE_VIEWED_BY_USERS_LIMIT = 3

  module CardType
    COMMENT                     = :comment
    POST                        = :post
    QA_ANSWER                   = :qa_answer
    ARTICLE_CREATION            = :article_creation
    ARTICLE_COMMENT_CREATION    = :article_comment_creation
    ANNOUNCEMENT_CREATION       = :announcement_creation
    ANNOUNCEMENT_UPDATE         = :announcement_update

    ICON_FOR = {
      COMMENT                   => PublicIcons::DigestV2::CARD_COMMENT_OR_POST_ICON,
      POST                      => PublicIcons::DigestV2::CARD_COMMENT_OR_POST_ICON,
      QA_ANSWER                 => PublicIcons::DigestV2::QA_ANSWER_ICON,
      ARTICLE_CREATION          => PublicIcons::DigestV2::ARTICLE_COMMENT_OR_ARTICLE_CREATION_ICON,
      ARTICLE_COMMENT_CREATION  => PublicIcons::DigestV2::ARTICLE_COMMENT_OR_ARTICLE_CREATION_ICON,
      ANNOUNCEMENT_CREATION     => PublicIcons::DigestV2::ANNOUNCEMENT_RELATED_ICON,
      ANNOUNCEMENT_UPDATE       => PublicIcons::DigestV2::ANNOUNCEMENT_RELATED_ICON
    }
  end

  module PopularContentType
    TOPIC                       = :topic
    ARTICLE                     = :article
    QA_QUESTION                 = :qa_question

    module Priority
      ARTICLE                   = 1
      TOPIC                     = 2
      QA_QUESTION               = 3
    end

    ICON_FOR = {
      TOPIC                     => PublicIcons::DigestV2::CARD_COMMENT_OR_POST_ICON,
      QA_QUESTION               => PublicIcons::DigestV2::QA_ANSWER_ICON,
      ARTICLE                   => PublicIcons::DigestV2::ARTICLE_COMMENT_OR_ARTICLE_CREATION_ICON
    }
  end

  def digest_v2(user, options)
    user_id = user.id
    @user = User.includes(:member, :received_mentor_requests, :received_meeting_requests, :received_mentor_offers, roles: [:translations], program: [organization: [program_asset: [:translations]], program_asset: [:translations]], pending_notifications: [:ref_obj, :ref_obj_creator], connection_memberships: [:pending_notifications]).find_by(id: user_id)
    return nil unless @user
    set_basic_vars
    set_digest_mail_detail_vars(options)
    return nil unless digest_mail_needed_after_analyzing_content?
    DigestV2.instance_variable_get(:"@mailer_attributes")[:subject] = Proc.new{ get_dynamic_subject }
    init_mail
    render_mail
  end

  private

  def init_mail
    set_program(@user.program)
    set_username(@user)
    setup_email(@user)
    super
    set_layout_options(program: @program, email_body_margin_bottom: 0, show_change_notif_link: true)
  end

  def set_basic_vars
    @member = @user.member
    @program = @user.program
    @custom_term_hash = @program.return_custom_term_hash
    @current_organization = @program.organization
    @url_options = {subdomain: @current_organization.subdomain, domain: @current_organization.domain, root: @program.root, src: :digest_v2}
  end

  def digest_mail_needed_after_analyzing_content?
    @total_activity_count > 0 # send email if content present
  end

  def get_card_details
    DigestV2::USER_PENDING_NOTIFICATION_BY_PRIORITY.map { |notification_type| compiled_notification_hash(@user_pending_notifications[notification_type] || []) }.flatten.compact
  end

  def set_program_updates_mail_related_details(options)
    @user_pending_notifications = {}
    @popular_content_card_details = []
    @viewed_by_users = []
    if @user.digest_v2_program_update_required?
      @user_pending_notifications = @user.pending_notifications.select{ |pending_notification| pending_notification.ref_obj.present? }.group_by(&:action_type)
      @popular_content_card_details = ((@user.last_program_update_sent_time > Time.current.beginning_of_month)? [] : get_popular_content_card_details(options[:most_viewed_content_details]))
      # this is temporarily hidden from getting displayed in email, will be revisited and enabled in future
      # @viewed_by_users = @user.ordered_viewed_by_users_from_last_program_update(PROFILE_VIEWED_BY_USERS_LIMIT)
    end
    @card_details = get_card_details
  end

  def set_digest_mail_detail_vars(options)
    @selected_connection_memberships, @selected_connection_membership_details = @user.get_selected_connection_membership_and_details_for_digest_v2
    set_program_updates_mail_related_details(options)
    @total_activity_count = @card_details.size + @selected_connection_memberships.size + @popular_content_card_details.size + (@viewed_by_users.present? ? 1 : 0)
    return unless digest_mail_needed_after_analyzing_content? # avoid further computations
    update_roll_up_details
  end

  def get_popular_content_object_key(object)
    hsh = {}
    case object
    when Topic
      hsh[:card_content] = object.title
      hsh[:call_to_action_url] = [:forum_topic_url, object.forum, object]
      hsh[:authors] = [object.user]
      [PopularContentType::TOPIC, hsh]
    when Article
      hsh[:card_content] = object.title
      hsh[:call_to_action_url] = [:article_url, object]
      hsh[:authors] = [object.author]
      [PopularContentType::ARTICLE, hsh]
    when QaQuestion
      hsh[:card_content] = object.summary
      hsh[:call_to_action_url] = [:qa_question_url, object]
      hsh[:authors] = [object.user]
      [PopularContentType::QA_QUESTION, hsh]
    end
  end

  def get_popular_content_subject(key, hsh)
    ["email_translations.digest_v2.popular_content.subject.#{key}".translate(@custom_term_hash), "'#{hsh[:card_content]}'"].join(" - ")
  end

  def get_popular_content_card_details(object_identifiers)
    allowed_role_ids = @user.role_ids + [nil] # nil represents role checks not applicable
    objects = []
    object_identifiers.select{|hsh|hsh[:role_id].in?(allowed_role_ids)}.each do |hsh|
      object = hsh[:klass].constantize.find_by(id: hsh[:id])
      next unless object
      objects << object unless objects.include?(object)
      break if objects.size >= DigestV2Utils::Trigger::MOST_VIEWED_CONTENT_COUNT
    end
    objects.map do |object|
      key, hsh = get_popular_content_object_key(object)
      author_names = hsh[:authors].map{ |author| author.name(name_only: true) }
      hsh[:icon_src] = PopularContentType::ICON_FOR[key]
      hsh[:card_footer] = "email_translations.digest_v2.by_authors".translate(list_of_authors: ary_to_sentence_with_x_more(author_names, 2))
      hsh[:card_heading] = "email_translations.digest_v2.popular_content.heading.#{key}".translate(@custom_term_hash)
      hsh[:subject] = get_popular_content_subject(key, hsh)
      hsh
    end
  end

  def update_roll_up_details
    @received_requests_count, @received_requests_call_to_action = @user.get_received_requests_count_and_action
    @unread_inbox_messages_count = @member.inbox_unread_count
    @unread_inbox_messages_call_to_action = [:messages_url, {organization_level: true, :"search_filters[status][unread]" => AbstractMessageReceiver::Status::UNREAD, tab: MessageConstants::Tabs::INBOX}]
    @upcoming_not_responded_meetings_count = @member.get_upcoming_not_responded_meetings_count(@program)
    @upcoming_not_responded_meetings_call_to_action = [:member_url, @member, {tab: MembersController::ShowTabs::AVAILABILITY}]
  end

  def get_membership_upcoming_and_pending_tasks_size(membership)
    @selected_connection_membership_details[membership.id][:upcoming_tasks].size + @selected_connection_membership_details[membership.id][:pending_tasks].size
  end

  def get_membership_related_details_for_computing_subject
    membership_related_details = {upcoming_and_pending_tasks_size: 0, pending_notifications_size: 0}
    @selected_connection_memberships.each do |membership|
      this_membership_upcoming_and_pending_tasks_size = get_membership_upcoming_and_pending_tasks_size(membership)
      this_membership_pending_notifications_size = @selected_connection_membership_details[membership.id][:pending_notifications].size
      if (this_membership_upcoming_and_pending_tasks_size > membership_related_details[:upcoming_and_pending_tasks_size]) || (membership_related_details[:upcoming_and_pending_tasks_size] == this_membership_upcoming_and_pending_tasks_size && this_membership_pending_notifications_size > membership_related_details[:pending_notifications_size])
        membership_related_details[:upcoming_and_pending_tasks_size] = this_membership_upcoming_and_pending_tasks_size
        membership_related_details[:membership] = membership
        membership_related_details[:pending_notifications_size] = this_membership_pending_notifications_size
      end
    end
    membership_related_details
  end

  def update_subject_with_n_more_updates!(subject, n = nil)
    n = (@total_activity_count - 1) unless n
    subject << " #{"email_translations.digest_v2.subject.and_n_updates".translate(count: n)}" if n > 0
    subject
  end

  # ary_to_sentence_with_x_more(["Jon", "Ken", "Von"], 2) => "Jon, Ken and 1 more"
  def ary_to_sentence_with_x_more(ary, first_part_count)
    tmp = ary.first(first_part_count)
    tmp << "display_string.more_with_count".translate(count: (ary.size - tmp.size)) if ary.size > tmp.size
    tmp.to_sentence
  end

  def get_base_details(pending_notifications)
    pending_notifications.map do |pending_notification|
      pending_notification.digest_v2_card_base_details.merge!({
        author: pending_notification.digest_v2_card_author_name,
        type: pending_notification.digest_v2_card_type
      })
    end
  end

  def get_card_heading(card_type, count)
    options = {count: count}
    case card_type
    when DigestV2::CardType::COMMENT
      "email_translations.digest_v2.card_heading.comment".translate(options)
    when DigestV2::CardType::POST, DigestV2::CardType::ARTICLE_COMMENT_CREATION
      "email_translations.digest_v2.card_heading.post".translate(options)
    when DigestV2::CardType::QA_ANSWER
      "email_translations.digest_v2.card_heading.qa_answer".translate(options)
    when DigestV2::CardType::ARTICLE_CREATION
      "email_translations.digest_v2.card_heading.article_creation".translate(options.merge!({a_article: @custom_term_hash[:_a_article]}))
    when DigestV2::CardType::ANNOUNCEMENT_CREATION
      "email_translations.digest_v2.card_heading.announcement_created".translate(options)
    when DigestV2::CardType::ANNOUNCEMENT_UPDATE
      "email_translations.digest_v2.card_heading.announcement_updated".translate(options)
    end
  end

  def get_card_subject(card_type, detail = {})
    authors_text = ary_to_sentence_with_x_more(detail[:authors], 1)
    case card_type
    when DigestV2::CardType::COMMENT, DigestV2::CardType::POST
      "email_translations.digest_v2.subject.new_post_or_comment".translate(authors: authors_text, topic_name: detail[:card_content])
    when DigestV2::CardType::QA_ANSWER
      "email_translations.digest_v2.subject.qa_answer".translate(authors: authors_text, question_summary: detail[:card_content])
    when DigestV2::CardType::ARTICLE_CREATION
      "email_translations.digest_v2.subject.new_article".translate(authors: authors_text, article_title: detail[:card_content], article: @custom_term_hash[:_article])
    when DigestV2::CardType::ARTICLE_COMMENT_CREATION
      "email_translations.digest_v2.subject.new_article_comment".translate(authors: authors_text, article_title: detail[:card_content])
    when DigestV2::CardType::ANNOUNCEMENT_CREATION
      "email_translations.digest_v2.subject.announcement_created".translate
    when DigestV2::CardType::ANNOUNCEMENT_UPDATE
      "email_translations.digest_v2.subject.announcement_updated".translate
    end
  end

  def compute_single_card_hash(details_ary)
    detail = details_ary.first
    card_type = detail[:type]
    authors = details_ary.map{ |hsh| hsh[:author] }.uniq
    hsh = {}
    hsh[:card_content] = detail[:content]
    hsh[:call_to_action_url] = detail[:call_to_action_url]
    hsh[:authors] = authors
    hsh[:icon_src] = DigestV2::CardType::ICON_FOR[card_type]
    hsh[:card_footer] = "email_translations.digest_v2.by_authors".translate(list_of_authors: ary_to_sentence_with_x_more(authors, 2))
    hsh[:card_heading] = get_card_heading(card_type, details_ary.size)
    hsh[:subject] = get_card_subject(card_type, hsh)
    hsh
  end

  def compiled_notification_hash(pending_notifications)
    base_details = get_base_details(pending_notifications)
    grouped_base_details = base_details.group_by{ |hsh| "#{hsh[:content_id]}_#{hsh[:type]}" }.values
    grouped_base_details.map { |ary_hsh| compute_single_card_hash(ary_hsh) }
  end

  def get_connection_updates_and_activity_subject(membership_related_details, user_name)
    membership = membership_related_details[:membership]
    pending_notifications = @selected_connection_membership_details[membership.id][:pending_notifications]
    group_name = membership.group.name
    case pending_notifications.first.action_type
    when RecentActivityConstants::Type::USER_SUSPENSION, RecentActivityConstants::Type::GROUP_MEMBER_LEAVING, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
      "email_translations.digest_v2.subject.group_members_change".translate(group_name: group_name, user_name: user_name, _Mentoring_Connection: @custom_term_hash[:_Mentoring_Connection])
    when RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE
      "email_translations.digest_v2.subject.change_expiry_date".translate(group_name: group_name, user_name: user_name)
    when RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION
      count = pending_notifications.select{ |notification| [RecentActivityConstants::Type::TOPIC_CREATION, RecentActivityConstants::Type::POST_CREATION].include?(notification.action_type) }.map{|notification| notification.digest_v2_card_base_details[:content_id] }.uniq.size
      "email_translations.digest_v2.subject.discussion_board_new_post_or_topic".translate(group_name: group_name, user_name: user_name, count: count)
    when RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION
      "email_translations.digest_v2.subject.task_created_to_you".translate(group_name: group_name, user_name: user_name, count: pending_notifications.select{ |notification| notification.action_type == RecentActivityConstants::Type::MENTORING_MODEL_TASK_CREATION }.size)
    end
  end

  def suggested_next_steps_upcoming_pending_tasks_subject_needed?(membership_related_details)
    membership_related_details[:membership] && membership_related_details[:upcoming_and_pending_tasks_size] > 0 && @program.mentoring_connections_v2_enabled?
  end

  def subject_due_to_connection_membership
    user_name = @user.name(name_only: true)
    membership_related_details = get_membership_related_details_for_computing_subject

    # Suggested next steps ( upcoming & pending tasks)
    if suggested_next_steps_upcoming_pending_tasks_subject_needed?(membership_related_details)
      subject = "email_translations.digest_v2.subject.suggested_next_steps_v2".translate(group_name: membership_related_details[:membership].group.name, user_name: user_name, count: membership_related_details[:upcoming_and_pending_tasks_size])
      return update_subject_with_n_more_updates!(subject)
    end

    # Connection updates and activity
    if membership_related_details[:membership] && membership_related_details[:pending_notifications_size] > 0
      return update_subject_with_n_more_updates!(get_connection_updates_and_activity_subject(membership_related_details, user_name))
    end

    nil
  end

  def get_card_subject_with_n_more_updates(card_details)
    update_subject_with_n_more_updates!("#{@user.name(name_only: true)}, #{card_details.first[:subject]}")
  end

  def get_dynamic_subject
    subject = subject_due_to_connection_membership
    if subject
      subject
    elsif @card_details.present? # user pending notfication related subject
      get_card_subject_with_n_more_updates(@card_details)
    elsif @viewed_by_users.present? # user profile views related subject
      update_subject_with_n_more_updates!("email_translations.digest_v2.subject.profile_viewed".translate(user_name: @user.name(name_only: true), count: @viewed_by_users.size))
    elsif @popular_content_card_details.present? # popular content based subject
      get_card_subject_with_n_more_updates(@popular_content_card_details)
    end
  end

  register_tags do
    # description & example not applicable
    tag :digest_v2_content, description: Proc.new{''}, example: Proc.new{''} do
      render(partial: '/digest_v2').html_safe
    end
  end

  self.register!
end
