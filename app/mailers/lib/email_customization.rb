module EmailCustomization
  module NewCategories
    module SubCategories
      APPLY_TO_JOIN = 1
      ADMIN_ADDING_USERS = 2
      WELCOME_MESSAGES = 3
      ANNOUNCEMENTS = 4
      ARTICLES = 5
      ENGAGEMENT = 6
      OTHERS = 7
      FORUMS = 8
      USER_MANAGEMENT = 9
      ADMIN_INITIATED_MATCHING = 10
      MENTORING_CONNECTIONS_NOTIFICATION = 11
      MENTORING_OFFERS = 12
      NEW_CIRCLES_CREATION = 13
      INVITATION = 14
      MEETINGS = 15
      MEETING_REQUEST_RELATED = 16
      MENTOR_REQUEST_RELATED = 17
      EVENTS = 18
      CIRCLE_REQUEST_RELATED = 19
      QA_RELATED = 20

      NAMES = {
        APPLY_TO_JOIN => "apply_to_join",
        ADMIN_ADDING_USERS => "admin_adding_users_v1",
        WELCOME_MESSAGES => "welcome_messages",
        ARTICLES => "articles_v1",
        OTHERS => "others_v1",
        FORUMS => "forums",
        USER_MANAGEMENT => "user_management_v1",
        ADMIN_INITIATED_MATCHING => "admin_initiated_matching_v1",
        MENTORING_CONNECTIONS_NOTIFICATION => "mentoring_connections_notification_v1",
        MENTORING_OFFERS => "mentoring_offers",
        NEW_CIRCLES_CREATION => "new_circles_creation",
        INVITATION => "invitation_v1",
        MEETINGS => "meetings",
        MEETING_REQUEST_RELATED => "meeting_requests_related",
        MENTOR_REQUEST_RELATED => "mentor_requests_related",
        EVENTS => "events",
        CIRCLE_REQUEST_RELATED => "circle_request_related",
        QA_RELATED => "qa_related"
      }
    end

    module Type
      ENROLLMENT_AND_USER_MANAGEMENT = 1
      MATCHING_AND_ENGAGEMENT = 2
      THREE_SIXTY_RELATED = 3
      COMMUNITY = 4
      ADMINISTRATION_EMAILS = 5
      DIGEST_AND_WEEKLY_UPDATES = 6

      def self.all
        (ENROLLMENT_AND_USER_MANAGEMENT..DIGEST_AND_WEEKLY_UPDATES)
      end


      SubCategoriesForType = {
        ENROLLMENT_AND_USER_MANAGEMENT => [SubCategories::APPLY_TO_JOIN, SubCategories::INVITATION, SubCategories::ADMIN_ADDING_USERS, SubCategories::WELCOME_MESSAGES, SubCategories::USER_MANAGEMENT],
        COMMUNITY => [SubCategories::EVENTS, SubCategories::FORUMS, SubCategories::ARTICLES, SubCategories::QA_RELATED, SubCategories::OTHERS],
        MATCHING_AND_ENGAGEMENT => [SubCategories::NEW_CIRCLES_CREATION, SubCategories::CIRCLE_REQUEST_RELATED, SubCategories::MEETING_REQUEST_RELATED, SubCategories::MENTOR_REQUEST_RELATED, SubCategories::MENTORING_OFFERS, SubCategories::ADMIN_INITIATED_MATCHING, SubCategories::MEETINGS, SubCategories::MENTORING_CONNECTIONS_NOTIFICATION]
      }
    end

    NAMES = {
      Type::ENROLLMENT_AND_USER_MANAGEMENT => "enrollment_and_user_management_related",
      Type::ADMINISTRATION_EMAILS => "administration_mails_v1",
      Type::THREE_SIXTY_RELATED => "three_sixty_related_v1",
      Type::COMMUNITY => "community_related_v1",
      Type::MATCHING_AND_ENGAGEMENT => "matching_and_engagement_related_v1",
      Type::DIGEST_AND_WEEKLY_UPDATES => "digest_and_weekly_updates_v1"
    }
  end

  module MessageType
    COMMUNICATION = "communication"
  end

  def self.get_translated_email_type_name(title)
    Proc.new{|program| "feature.email.filter.#{title}".translate(program.return_custom_term_hash)}
  end

  def self.get_translated_email_description(title)
    Proc.new{|program| "feature.email.category_description.#{title}".translate(program.return_custom_term_hash)}
  end

  def self.get_translated_email_subcategory_name(title)
    Proc.new{|program| "feature.email.filter.subcategories.#{title}".translate(program.return_custom_term_hash)}
  end

  def self.get_translated_email_category_description(title)
    Proc.new{|program| "feature.email.category_description.#{title}".translate(program.return_custom_term_hash)}
  end

  module Level
    ORGANIZATION = 0
    PROGRAM = 1

    def self.select_those_applicable_at_current_level(mailer_templates, current_level)
      allowed_level = current_level.is_a?(Program) ?  PROGRAM : ORGANIZATION
      mailer_templates.select{|m| allowed_level==m[:level]}
    end
  end
end
